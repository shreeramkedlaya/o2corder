CLASS lhc_OrderHeader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR OrderHeader RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OrderHeader RESULT result.

    METHODS shipOrder FOR MODIFY
      IMPORTING keys FOR ACTION OrderHeader~shipOrder RESULT result.

    METHODS cancelOrder FOR MODIFY
      IMPORTING keys FOR ACTION OrderHeader~cancelOrder RESULT result.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrderHeader~validateCustomer.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE OrderHeader.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR OrderHeader~setInitialStatus.

    METHODS earlynumbering_cba_Items FOR NUMBERING
      IMPORTING entities FOR CREATE OrderHeader\_Items.


ENDCLASS.

CLASS lhc_OrderHeader IMPLEMENTATION.

  " -------------------------------------------------------------
  " 1. DYNAMIC BUTTON CONTROL: Disable 'Ship Order' if already shipped
  " -------------------------------------------------------------
  METHOD get_instance_features.
    READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        FIELDS ( overall_status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    result = VALUE #( FOR ls_order IN lt_orders
                      ( %tky = ls_order-%tky

                        " Disable Ship button if already Shipped or Cancelled
                        %action-shipOrder = COND #( WHEN ls_order-overall_status = 'S' OR ls_order-overall_status = 'C'
                                                    THEN if_abap_behv=>fc-o-disabled
                                                    ELSE if_abap_behv=>fc-o-enabled )

                        " Disable Cancel button if already Cancelled or Shipped
                        %action-cancelOrder = COND #( WHEN ls_order-overall_status = 'C' OR ls_order-overall_status = 'S'
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled )
                      ) ).
  ENDMETHOD.


  " -------------------------------------------------------------
  " 2. GLOBAL AUTHORIZATIONS (Pass-through for trial/practice)
  " -------------------------------------------------------------
  METHOD get_global_authorizations.
  ENDMETHOD.

  " -------------------------------------------------------------
  " 3. ACTION IMPLEMENTATION: Ship Order
  " -------------------------------------------------------------
  METHOD shipOrder.
    " Update overall_status to 'S' (Shipped)
    MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( overall_status )
        WITH VALUE #( FOR key IN keys (
                        %tky           = key-%tky
                        overall_status = 'S'
                      ) )
      FAILED failed
      REPORTED reported.

    " Read updated record
    READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Return result to Fiori UI
    result = VALUE #( FOR ls_header IN lt_headers
                      ( %tky   = ls_header-%tky
                        %param = ls_header ) ).

    " Trigger the Toast Alert Message for Shipping
    LOOP AT lt_headers INTO DATA(ls_order_msg).
      APPEND VALUE #(
          %tky = ls_order_msg-%tky
          %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-success
              text = |Success! Order { ls_order_msg-order_id } was shipped.|
          )
      ) TO reported-orderheader.
    ENDLOOP.
  ENDMETHOD.

  " -------------------------------------------------------------
  " 4. VALIDATION ON SAVE: Ensure Customer ID is not empty
  " -------------------------------------------------------------
  METHOD validateCustomer.
    READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        FIELDS ( customer_id ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    LOOP AT lt_orders INTO DATA(ls_order).
      IF ls_order-customer_id IS INITIAL.
        APPEND VALUE #( %tky = ls_order-%tky ) TO failed-orderheader.
        APPEND VALUE #( %tky = ls_order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Customer ID is mandatory!'
                               ) ) TO reported-orderheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " -------------------------------------------------------------
  " 5. ACTION IMPLEMENTATION: Cancel Order
  " -------------------------------------------------------------
  METHOD cancelorder.
    "1. update overall_status to cancelled
    MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( overall_status )
        WITH VALUE #( FOR key IN keys (
                        %tky = key-%tky
                        overall_status = 'C'
                        ) )
        FAILED failed
        REPORTED reported.

    "2. read the updated record back
    READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    "3. return the result back to the UI
    result = VALUE #( FOR ls_order IN lt_orders
                      ( %tky = ls_order-%tky
                        %param = ls_order ) ).

    "4. trigger the toast alert message for Cancelling
    LOOP AT lt_orders INTO DATA(ls_order_msg).
      APPEND VALUE #(
          %tky = ls_order_msg-%tky
          %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-success
              text = |Success! Order { ls_order_msg-order_id } was cancelled.|
          )
      ) TO reported-orderheader.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA: lv_max_id TYPE n LENGTH 4.

    " 1. Find the highest Order ID across BOTH Active AND Draft tables!
    SELECT MAX( order_id ) FROM ztab_o2c_hd INTO @DATA(lv_max_active).
    SELECT MAX( order_id ) FROM zdr_o2c_hd  INTO @DATA(lv_max_draft).

    DATA(lv_highest_order) = COND string( WHEN lv_max_active > lv_max_draft
                                          THEN lv_max_active
                                          ELSE lv_max_draft ).

    " Extract just the numbers safely
    IF lv_highest_order IS NOT INITIAL AND strlen( lv_highest_order ) >= 4.
      TRY.
          lv_max_id = substring( val = lv_highest_order off = 4 ).
        CATCH cx_root.
          lv_max_id = 0.
      ENDTRY.
    ELSE.
      lv_max_id = 0.
    ENDIF.

    " 2. Assign the next chronological number to all new drafts being created
    LOOP AT entities INTO DATA(ls_entity).
      IF ls_entity-order_id IS INITIAL.
        lv_max_id += 1.
        APPEND VALUE #( %cid      = ls_entity-%cid
                        %is_draft = ls_entity-%is_draft
                        order_id  = |ORD-{ lv_max_id }| ) TO mapped-orderheader.
      ELSE.
        APPEND VALUE #( %cid      = ls_entity-%cid
                        %is_draft = ls_entity-%is_draft
                        order_id  = ls_entity-order_id ) TO mapped-orderheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setInitialStatus.
    MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( overall_status )
        WITH VALUE #( FOR key IN keys (
                        %tky           = key-%tky
                        overall_status = 'D' " Set default status to Draft
                      ) ).
  ENDMETHOD.

  METHOD earlynumbering_cba_Items.
    DATA: lv_max_item_pos TYPE ztab_o2c_it-item_position.

    LOOP AT entities INTO DATA(ls_header).

      " 1. Read existing items from the Transactional Buffer (this respects draft deletions!)
      READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
        ENTITY OrderHeader BY \_Items
          FIELDS ( item_position ) WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_existing_items).

      " 2. Find the highest existing item position in the buffer
      lv_max_item_pos = 0.
      LOOP AT lt_existing_items INTO DATA(ls_existing_item).
        IF ls_existing_item-item_position > lv_max_item_pos.
          lv_max_item_pos = ls_existing_item-item_position.
        ENDIF.
      ENDLOOP.

      " 3. Assign new positions in increments of 10
      LOOP AT ls_header-%target INTO DATA(ls_item).
        lv_max_item_pos += 10.

        APPEND VALUE #( %cid          = ls_item-%cid
                        %is_draft     = ls_item-%is_draft
                        order_id      = ls_header-order_id
                        item_position = lv_max_item_pos ) TO mapped-orderitem.
      ENDLOOP.

    ENDLOOP.
  ENDMETHOD.



ENDCLASS.


" =====================================================================
" ITEM LEVEL HANDLER: Price Orchestration & Header Rollup
" =====================================================================
CLASS lhc_OrderItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS calculateItemTotal FOR DETERMINE ON MODIFY
      IMPORTING keys FOR OrderItem~calculateItemTotal.
ENDCLASS.

CLASS lhc_OrderItem IMPLEMENTATION.
  METHOD calculateItemTotal.
    READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderItem
        FIELDS ( material_id quantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_changed_items).

    IF lt_changed_items IS INITIAL.
      RETURN.
    ENDIF.

    " 1. UPDATE BOTH AMOUNT AND CURRENCY CODE
    MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderItem
        UPDATE FIELDS ( item_amount currency_code )
        WITH VALUE #( FOR item IN lt_changed_items (
                        %tky          = item-%tky
                        item_amount   = item-quantity * COND #( WHEN item-material_id = 'MAT-100' THEN 150
                                                                WHEN item-material_id = 'MAT-200' THEN 300
                                                                WHEN item-material_id = 'MAT-300' THEN 450
                                                                ELSE 50 )
                        currency_code = 'USD' " <-- REQUIRED FOR FIORI TO DISPLAY IT!
                      ) ).

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zi_o2c_hd.
    lt_header_keys = VALUE #( FOR GROUPS header_grp OF item IN lt_changed_items
                              GROUP BY ( order_id = item-order_id  is_draft = item-%is_draft )
                              ( %tky-order_id = header_grp-order_id
                                %tky-%is_draft = header_grp-is_draft ) ).

    LOOP AT lt_header_keys INTO DATA(ls_header_key).

      READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
        ENTITY OrderHeader BY \_Items
          FIELDS ( item_amount ) WITH VALUE #( ( %tky = ls_header_key-%tky ) )
        RESULT DATA(lt_all_current_items).

      " 2. FIX TYPE CONVERSION IN REDUCE (INIT sum must match the currency type)
      DATA(lv_grand_total) = REDUCE #( INIT sum TYPE zdr_o2c_hd-total_amount
                                       FOR ls_all_item IN lt_all_current_items
                                       NEXT sum = sum + ls_all_item-item_amount ).

      MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
        ENTITY OrderHeader
          UPDATE FIELDS ( total_amount currency_code )
          WITH VALUE #( ( %tky           = ls_header_key-%tky
                          total_amount   = lv_grand_total
                          currency_code  = 'USD' ) )
          REPORTED DATA(lt_reported_hd).

      reported-orderheader = CORRESPONDING #( BASE ( reported-orderheader ) lt_reported_hd-orderheader ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

