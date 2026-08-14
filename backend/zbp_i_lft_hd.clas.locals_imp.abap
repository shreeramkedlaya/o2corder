CLASS lhc_OrderHeader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR OrderHeader RESULT result.
ENDCLASS.

CLASS lhc_OrderHeader IMPLEMENTATION.
  METHOD get_instance_authorizations.
    " Allow all actions for now
  ENDMETHOD.
ENDCLASS.

CLASS lhc_OrderItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS generateMilestones FOR DETERMINE ON SAVE
      IMPORTING keys FOR OrderItem~generateMilestones.
ENDCLASS.

CLASS lhc_OrderItem IMPLEMENTATION.
  METHOD generateMilestones.
    " 1. Read the newly created items
    READ ENTITIES OF zi_lft_hd IN LOCAL MODE
         ENTITY OrderItem
         FIELDS ( ItemAmount Currency ) WITH CORRESPONDING #( keys )
         RESULT DATA(lt_items).

    DATA: lt_bplan TYPE TABLE FOR CREATE zi_lft_it\_BillingPlan.

    " 2. Calculate the 4 milestones for each item
    LOOP AT lt_items INTO DATA(ls_item).
      DATA(lv_amount) = ls_item-ItemAmount.

      APPEND VALUE #( %tky = ls_item-%tky
                      %target = VALUE #(
                        " 10% Advance
                        ( %cid = 'M1'
                          MilestoneId = '0010'
                          MilestoneType = 'ADV'
                          PhaseId = '1'
                          Percentage = 10
                          Amount = lv_amount * '0.10'
                          Currency = ls_item-Currency
                          Status = 'P'
                          %control = VALUE #(
                          MilestoneId = if_abap_behv=>mk-on
                          MilestoneType = if_abap_behv=>mk-on
                          PhaseId = if_abap_behv=>mk-on
                          Percentage = if_abap_behv=>mk-on
                          Amount = if_abap_behv=>mk-on
                          Currency = if_abap_behv=>mk-on
                          Status = if_abap_behv=>mk-on ) )
                        " 30% Material
                        ( %cid = 'M2'
                          MilestoneId = '0020'
                          MilestoneType = 'MAT'
                          PhaseId = '1'
                          Percentage = 30
                          Amount = lv_amount * '0.30'
                          Currency = ls_item-Currency
                          Status = 'P'
                          %control = VALUE #(
                          MilestoneId = if_abap_behv=>mk-on
                          MilestoneType = if_abap_behv=>mk-on
                          PhaseId = if_abap_behv=>mk-on
                          Percentage = if_abap_behv=>mk-on
                          Amount = if_abap_behv=>mk-on
                          Currency = if_abap_behv=>mk-on
                          Status = if_abap_behv=>mk-on ) )
                        " 40% Installation
                        ( %cid = 'M3'
                          MilestoneId = '0030'
                          MilestoneType = 'INS'
                          PhaseId = '2'
                          Percentage = 40
                          Amount = lv_amount * '0.40'
                          Currency = ls_item-Currency
                          Status = 'P'
                          %control = VALUE #(
                          MilestoneId = if_abap_behv=>mk-on
                          MilestoneType = if_abap_behv=>mk-on
                          PhaseId = if_abap_behv=>mk-on
                          Percentage = if_abap_behv=>mk-on
                          Amount = if_abap_behv=>mk-on
                          Currency = if_abap_behv=>mk-on
                          Status = if_abap_behv=>mk-on ) )
                        " 20% Testing
                        ( %cid = 'M4'
                          MilestoneId = '0040'
                          MilestoneType = 'TST'
                          PhaseId = '2'
                          Percentage = 20
                          Amount = lv_amount * '0.20'
                          Currency = ls_item-Currency
                          Status = 'P'
                          %control = VALUE #(
                          MilestoneId = if_abap_behv=>mk-on
                          MilestoneType = if_abap_behv=>mk-on
                          PhaseId = if_abap_behv=>mk-on
                          Percentage = if_abap_behv=>mk-on
                          Amount = if_abap_behv=>mk-on
                          Currency = if_abap_behv=>mk-on
                          Status = if_abap_behv=>mk-on ) )
                      ) ) TO lt_bplan.
    ENDLOOP.

    " 3. Save the 4 rows to the database using EML
    IF lt_bplan IS NOT INITIAL.
      MODIFY ENTITIES OF zi_lft_hd IN LOCAL MODE
             ENTITY OrderItem
             CREATE BY \_BillingPlan
             FROM lt_bplan.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_BillingPlan DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS generateInvoice FOR MODIFY
      IMPORTING keys FOR ACTION BillingPlan~generateInvoice RESULT result.
ENDCLASS.

CLASS lhc_BillingPlan IMPLEMENTATION.
  METHOD generateInvoice.
    DATA: lv_next_id TYPE n LENGTH 5.

    " 1. Query the database to find the highest existing Invoice ID
    SELECT MAX( invoice_id ) FROM ztab_lft_bplan INTO @DATA(lv_max_id).

    IF lv_max_id IS NOT INITIAL AND strlen( lv_max_id ) >= 4.
      TRY.
          " Strip out the 'INV-' prefix to get the numeric part
          lv_next_id = substring( val = lv_max_id off = 4 ).
        CATCH cx_root.
          lv_next_id = 0.
      ENDTRY.
    ELSE.
      lv_next_id = 0.
    ENDIF.

    " 2. Read selected milestone row
    READ ENTITIES OF zi_lft_hd IN LOCAL MODE
         ENTITY BillingPlan
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(lt_milestones).

    DATA: lt_update TYPE TABLE FOR UPDATE zi_lft_hd\\BillingPlan.

    LOOP AT lt_milestones INTO DATA(ls_milestone).
      " 3. Increment ID and change status to 'Invoiced'
      lv_next_id += 1.
      APPEND VALUE #( %tky = ls_milestone-%tky
                      Status = 'I'
                      InvoiceId = |INV-{ lv_next_id }|
                      %control = VALUE #( Status = if_abap_behv=>mk-on InvoiceId = if_abap_behv=>mk-on )
                    ) TO lt_update.
    ENDLOOP.

    " 4. Update the rows in the database
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_lft_hd IN LOCAL MODE
             ENTITY BillingPlan
             UPDATE FROM lt_update.
    ENDIF.

    " 5. Return the refreshed data back to the UI so it instantly updates on screen
    READ ENTITIES OF zi_lft_hd IN LOCAL MODE
         ENTITY BillingPlan
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT lt_milestones.

    result = VALUE #( FOR ls_m IN lt_milestones ( %tky = ls_m-%tky %param = ls_m ) ).
  ENDMETHOD.
ENDCLASS.

