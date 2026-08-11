CLASS lhc_DeliveryHeader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DeliveryHeader RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DeliveryHeader RESULT result.

    METHODS postGoodsIssue FOR MODIFY
      IMPORTING keys FOR ACTION DeliveryHeader~postGoodsIssue RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE DeliveryHeader.

    METHODS earlynumbering_cba_Deliveryite FOR NUMBERING
      IMPORTING entities FOR CREATE DeliveryHeader\_DeliveryItems.

    METHODS createInvoice FOR MODIFY
      IMPORTING keys FOR ACTION DeliveryHeader~createInvoice RESULT result.

ENDCLASS.

CLASS lhc_DeliveryHeader IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
      ENTITY DeliveryHeader
        FIELDS ( delivery_status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_deliveries).

    result = VALUE #( FOR ls_del IN lt_deliveries
                      ( %tky = ls_del-%tky
                        %action-postGoodsIssue = COND #( WHEN ls_del-delivery_status = 'G' OR ls_del-delivery_status = 'D'
                                                         THEN if_abap_behv=>fc-o-disabled
                                                         ELSE if_abap_behv=>fc-o-enabled )
                      ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD postGoodsIssue.
    READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
    ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_deliveries).

    LOOP AT lt_deliveries INTO DATA(ls_del).
      "1. read del items to get qties
      READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
          ENTITY DeliveryHeader BY \_DeliveryItems
              FIELDS ( material_id quantity_ordered quantity_delivered )
              WITH VALUE #( ( %tky = ls_del-%tky ) )
          RESULT DATA(lt_items).

      "2. reduce stock in MM
      LOOP AT lt_items INTO DATA(ls_item).
        "if quantity_delivered was filled out, use it, otherwise assyme ordererd qty was Shipped
        DATA(lv_qty_to_deduct) = COND #(
                                        WHEN ls_item-quantity_delivered > 0
                                        THEN ls_item-quantity_delivered
                                        ELSE ls_item-quantity_ordered ).
        APPEND VALUE #( material_id = ls_item-material_id
                       quantity    = lv_qty_to_deduct ) TO zbp_i_o2c_del_hd=>gt_stock_updates.
      ENDLOOP.

      "3. set del status to 'G' (goods issued)
      MODIFY ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
        ENTITY DeliveryHeader UPDATE FIELDS ( delivery_status goods_issue_date )
        WITH VALUE #( ( %tky = ls_del-%tky
        delivery_status = 'G'
        goods_issue_date = cl_abap_context_info=>get_system_date( ) ) ).

      "4. update parent sales order status to 'S' (Shipped)
      " We must target the ACTIVE order version specifically
      MODIFY ENTITIES OF zi_o2c_hd
      ENTITY OrderHeader EXECUTE shipOrder
      FROM VALUE #( ( %tky-order_id = ls_del-order_id
                      %tky-%is_draft = if_abap_behv=>mk-off ) ).


      "5. Trigger Success Message
      APPEND VALUE #(
      %tky = ls_del-%tky
      %msg = new_message_with_text(
         severity = if_abap_behv_message=>severity-success
         text     = |Goods Issue posted! Stock reduced and Order { ls_del-order_id } marked Shipped.|
      )
      ) TO reported-deliveryheader.
    ENDLOOP.

    " return udpated delivery to ui
    READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
      ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated).

    result = VALUE #( FOR ls IN lt_updated ( %tky = ls-%tky %param = ls ) ).
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA: lv_next_id TYPE n LENGTH 5.

    " Check both Active and Draft tables for the highest ID
    SELECT MAX( delivery_id ) FROM ztab_o2c_del_hd INTO @DATA(lv_max_active).
    SELECT MAX( delivery_id ) FROM zdr_o2c_del_hd  INTO @DATA(lv_max_draft).

    DATA(lv_max_del) = COND string( WHEN lv_max_active > lv_max_draft
                                    THEN lv_max_active
                                    ELSE lv_max_draft ).

    " Extract the numeric portion (skipping 'DEL')
    IF lv_max_del IS NOT INITIAL AND strlen( lv_max_del ) >= 3.
      TRY.
          lv_next_id = substring( val = lv_max_del off = 3 ).
        CATCH cx_root.
          lv_next_id = 0.
      ENDTRY.
    ELSE.
      lv_next_id = 0.
    ENDIF.

    LOOP AT entities INTO DATA(ls_entity).
      IF ls_entity-delivery_id IS INITIAL.
        lv_next_id += 1.
        APPEND VALUE #( %cid        = ls_entity-%cid
                        %is_draft   = ls_entity-%is_draft
                        delivery_id = |DEL{ lv_next_id }| ) TO mapped-deliveryheader.
      ELSE.
        APPEND VALUE #( %cid        = ls_entity-%cid
                        %is_draft   = ls_entity-%is_draft
                        delivery_id = ls_entity-delivery_id ) TO mapped-deliveryheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD earlynumbering_cba_Deliveryite.
  ENDMETHOD.

  METHOD createInvoice.
    READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
      ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_deliveries).

    LOOP AT lt_deliveries INTO DATA(ls_del).
      IF ls_del-delivery_status <> 'G'. CONTINUE. ENDIF.

      " Get total amount and payment terms from the parent sales order
      READ ENTITIES OF zi_o2c_hd
        ENTITY OrderHeader FIELDS ( total_amount currency_code payment_terms customer_id )
        WITH VALUE #( ( %tky-order_id = ls_del-order_id
                        %tky-%is_draft = if_abap_behv=>mk-off ) )
        RESULT DATA(lt_orders).

      READ TABLE lt_orders INTO DATA(ls_order) INDEX 1.

      " Compute due date from payment terms
      DATA(lv_days) = COND i( WHEN ls_order-payment_terms = 'NT30' THEN 30
                              WHEN ls_order-payment_terms = 'NT60' THEN 60
                              WHEN ls_order-payment_terms = 'NT90' THEN 90
                              ELSE 30 ).
      DATA(lv_due_date) = cl_abap_context_info=>get_system_date(  ) + lv_days.
      DATA(lv_invoice_date) = cl_abap_context_info=>get_system_date(  ).

      " 1. Create invoice via EML (Notice we REMOVED invoice_id! Early Numbering will handle it)
      MODIFY ENTITIES OF zi_o2c_inv_hd
        ENTITY InvoiceHeader
          CREATE FIELDS ( order_id delivery_id customer_id invoice_date due_date
                          gross_amount outstanding_amount paid_amount
                          currency_code payment_terms ar_status )
          WITH VALUE #( ( %cid               = |cid_inv_{ ls_del-delivery_id }|
                          order_id           = ls_del-order_id
                          delivery_id        = ls_del-delivery_id
                          customer_id        = ls_del-customer_id
                          invoice_date       = lv_invoice_date
                          due_date           = lv_due_date
                          gross_amount       = ls_order-total_amount
                          outstanding_amount = ls_order-total_amount
                          paid_amount        = 0
                          currency_code      = ls_order-currency_code
                          payment_terms      = ls_order-payment_terms
                          ar_status          = 'O' ) )
          MAPPED DATA(mapped_inv) FAILED DATA(failed_env) REPORTED DATA(rep_inv).

      " 2. Update delivery_status to 'D' (invoiced)
      MODIFY ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
        ENTITY DeliveryHeader UPDATE FIELDS ( delivery_status )
        WITH VALUE #( (  %tky            = ls_del-%tky
                         delivery_status = 'D' ) ).

      " 3. Queue Sales Order status update for the Save Phase!
      APPEND VALUE #( order_id = ls_del-order_id
                      status   = 'I' ) TO zbp_i_o2c_del_hd=>gt_status_updates.

      " 4. Queue the Customer Credit Exposure update
      APPEND VALUE #( customer_id = ls_del-customer_id
                      amount      = ls_order-total_amount ) TO zbp_i_o2c_del_hd=>gt_credit_updates.

      " 5. Success Message
      APPEND VALUE #(
          %tky = ls_del-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-success
            text = |Invoice created! Due Date: { lv_due_date }. AR is Open.|
          )
      ) TO reported-deliveryheader.
    ENDLOOP.

    " Return updated delivery back to UI
    READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
      ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated).
    result = VALUE #( FOR ls IN lt_updated ( %tky = ls-%tky  %param = ls ) ).

  ENDMETHOD.


ENDCLASS.

" =====================================================================
" SAVER CLASS: Executes the deferred database updates safely
" =====================================================================
CLASS lsc_ZI_O2C_DEL_HD DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_O2C_DEL_HD IMPLEMENTATION.

  METHOD save_modified.
    " Safe to do direct DB updates here!
    LOOP AT zbp_i_o2c_del_hd=>gt_stock_updates INTO DATA(ls_update).
      UPDATE ztab_o2c_mat
        SET stock_quantity = stock_quantity - @ls_update-quantity
        WHERE material_id = @ls_update-material_id.
    ENDLOOP.

    " Phase 4: Execute Customer Credit Exposure Updates
    LOOP AT zbp_i_o2c_del_hd=>gt_credit_updates INTO DATA(ls_credit).
      UPDATE ztab_o2c_cust
        SET credit_exposure = credit_exposure + @ls_credit-amount
        WHERE customer_id = @ls_credit-customer_id.
    ENDLOOP.

    " Execute Sales Order Status Updates
    LOOP AT zbp_i_o2c_del_hd=>gt_status_updates INTO DATA(ls_status).
      UPDATE ztab_o2c_hd
        SET overall_status = @ls_status-status
        WHERE order_id = @ls_status-order_id.
    ENDLOOP.


  ENDMETHOD.

  METHOD cleanup_finalize.
    " Clear the memory so it doesn't accidentally run twice
    CLEAR zbp_i_o2c_del_hd=>gt_stock_updates.
    CLEAR zbp_i_o2c_del_hd=>gt_status_updates.
  ENDMETHOD.

ENDCLASS.

