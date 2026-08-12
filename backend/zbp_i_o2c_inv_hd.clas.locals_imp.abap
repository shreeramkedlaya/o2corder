CLASS lhc_InvoiceHeader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR InvoiceHeader RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR InvoiceHeader RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE InvoiceHeader.

    METHODS postPayment FOR MODIFY
      IMPORTING keys FOR ACTION InvoiceHeader~postPayment RESULT result.

ENDCLASS.

CLASS lhc_InvoiceHeader IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_o2c_inv_hd IN LOCAL MODE
      ENTITY InvoiceHeader
        FIELDS ( ar_status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_invoices).

    result = VALUE #( FOR ls_inv IN lt_invoices
                      ( %tky = ls_inv-%tky
                        " Disable Post Payment if Invoice is already Cleared (C)
                        %action-postPayment = COND #( WHEN ls_inv-ar_status = 'C'
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled )
                      ) ).
  ENDMETHOD.


  METHOD earlynumbering_create.
    DATA: lv_next_id TYPE n LENGTH 5.

    " Find the highest Invoice ID across both active and draft tables
    SELECT MAX( invoice_id ) FROM ztab_o2c_inv_hd INTO @DATA(lv_max_active).
    SELECT MAX( invoice_id ) FROM zdr_o2c_inv_hd INTO @DATA(lv_max_draft).
    DATA(lv_max_id) = COND #( WHEN lv_max_active > lv_max_draft THEN lv_max_active ELSE lv_max_draft ).

    IF lv_max_id IS INITIAL.
      lv_next_id = 1.
    ELSE.
      lv_next_id = lv_max_id+4(5) + 1. " Strip 'INV-' and increment
    ENDIF.

    LOOP AT entities INTO DATA(ls_entity).
      APPEND VALUE #( %cid       = ls_entity-%cid
                      %is_draft  = ls_entity-%is_draft
                      invoice_id = |INV-{ lv_next_id }| ) TO mapped-invoiceheader.
      lv_next_id += 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD postPayment.
    READ ENTITIES OF zi_o2c_inv_hd IN LOCAL MODE
      ENTITY InvoiceHeader ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_invoices).

    LOOP AT lt_invoices INTO DATA(ls_inv).
      IF ls_inv-ar_status = 'C'.  CONTINUE.  ENDIF. " Already cleared!

      " Get the popup parameters entered by the user
      READ TABLE keys INTO DATA(ls_key) WITH KEY id COMPONENTS %tky = ls_inv-%tky.
      DATA lv_new_paid        TYPE ztab_o2c_inv_hd-paid_amount.
      DATA lv_new_outstanding TYPE ztab_o2c_inv_hd-outstanding_amount.

      DATA(lv_pay_amount) = ls_key-%param-payment_amount.
      lv_new_paid         = ls_inv-paid_amount + lv_pay_amount.
      lv_new_outstanding  = ls_inv-gross_amount - lv_new_paid.


      DATA(lv_new_ar_status) = COND #( WHEN lv_new_outstanding <= 0 THEN 'C' ELSE 'P' ).

      " 1. Update Invoice AR fields
      MODIFY ENTITIES OF zi_o2c_inv_hd IN LOCAL MODE
        ENTITY InvoiceHeader UPDATE FIELDS ( paid_amount outstanding_amount ar_status )
        WITH VALUE #( ( %tky               = ls_inv-%tky
                        paid_amount        = lv_new_paid
                        outstanding_amount = lv_new_outstanding
                        ar_status          = lv_new_ar_status ) )
        FAILED failed  REPORTED reported.

      " 2. Queue Payment Record for DB Insertion in the Save Phase
      SELECT MAX( payment_id ) FROM ztab_o2c_pay INTO @DATA(lv_max_pay).
      DATA: lv_next_pay TYPE n LENGTH 6.
      IF lv_max_pay IS INITIAL.
        lv_next_pay = 1.
      ELSE.
        lv_next_pay = lv_max_pay+4(6) + 1.
      ENDIF.

      APPEND VALUE #(
          payment_id     = |PAY-{ lv_next_pay }|
          invoice_id     = ls_inv-invoice_id
          order_id       = ls_inv-order_id
          customer_id    = ls_inv-customer_id
          payment_date   = cl_abap_context_info=>get_system_date( )
          payment_amount = lv_pay_amount
          currency_code  = ls_inv-currency_code
          payment_method = ls_key-%param-payment_method
          reference      = ls_key-%param-reference
      ) TO zbp_i_o2c_inv_hd=>gt_payments.

      " 3. If Fully Cleared, queue Credit Exposure & Order Status updates
      IF lv_new_ar_status = 'C'.
        " Payment received! Deduct the amount from their exposure limit
        APPEND VALUE #( customer_id = ls_inv-customer_id
                        amount      = ls_inv-gross_amount ) TO zbp_i_o2c_inv_hd=>gt_credit_updates.

        " Mark original Sales Order as Paid
        APPEND VALUE #( order_id = ls_inv-order_id
                        status   = 'P' ) TO zbp_i_o2c_inv_hd=>gt_status_updates.
      ENDIF.

      " 4. Success Message
      APPEND VALUE #(
          %tky = ls_inv-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-success
            text = COND #( WHEN lv_new_ar_status = 'C'
                            THEN |Invoice { ls_inv-invoice_id } fully cleared!|
                            ELSE |Payment of { lv_pay_amount } posted. Outstanding: { lv_new_outstanding }| )
          )
      ) TO reported-invoiceheader.
    ENDLOOP.

    READ ENTITIES OF zi_o2c_inv_hd IN LOCAL MODE
      ENTITY InvoiceHeader ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated).
    result = VALUE #( FOR ls IN lt_updated ( %tky = ls-%tky  %param = ls ) ).
  ENDMETHOD.


ENDCLASS.

" =====================================================================
" SAVER CLASS: Executes the deferred database updates safely
" =====================================================================
CLASS lsc_ZI_O2C_INV_HD DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_O2C_INV_HD IMPLEMENTATION.
  METHOD save_modified.

    DATA lv_timestamp TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_timestamp.
    " Insert new Payment lines
    LOOP AT zbp_i_o2c_inv_hd=>gt_payments INTO DATA(ls_pay).
      INSERT ztab_o2c_pay FROM @( VALUE #(
        client         = sy-mandt
        payment_id     = ls_pay-payment_id
        invoice_id     = ls_pay-invoice_id
        order_id       = ls_pay-order_id
        customer_id    = ls_pay-customer_id
        payment_date   = ls_pay-payment_date
        payment_amount = ls_pay-payment_amount
        currency_code  = ls_pay-currency_code
        payment_method = ls_pay-payment_method
        reference      = ls_pay-reference
        created_by     = sy-uname
        created_at     = lv_timestamp
      ) ).
    ENDLOOP.

    " Reduce Customer Credit Exposure
    LOOP AT zbp_i_o2c_inv_hd=>gt_credit_updates INTO DATA(ls_credit).
      UPDATE ztab_o2c_cust
        SET credit_exposure = credit_exposure - @ls_credit-amount
        WHERE customer_id = @ls_credit-customer_id.
    ENDLOOP.

    " Update Sales Order to Paid
    LOOP AT zbp_i_o2c_inv_hd=>gt_status_updates INTO DATA(ls_status).
      UPDATE ztab_o2c_hd
        SET overall_status = @ls_status-status
        WHERE order_id = @ls_status-order_id.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR zbp_i_o2c_inv_hd=>gt_payments.
    CLEAR zbp_i_o2c_inv_hd=>gt_credit_updates.
    CLEAR zbp_i_o2c_inv_hd=>gt_status_updates.
  ENDMETHOD.
ENDCLASS.


