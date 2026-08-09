CLASS zcl_generate_o2c_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_generate_o2c_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA: lt_hd TYPE TABLE OF ztab_o2c_hd,
          lt_it TYPE TABLE OF ztab_o2c_it,
          ls_hd LIKE LINE OF lt_hd,
          ls_it LIKE LINE OF lt_it.

    " Clear existing data for the current client automatically
    DELETE FROM ztab_o2c_it.
    DELETE FROM ztab_o2c_hd.

    " Generate 100 Header Records with 3 Items each
    DO 100 TIMES.
      DATA(lv_index) = sy-index.
      DATA(lv_order_id) = |OR{ lv_index WIDTH = 5 ALIGN = RIGHT PAD = '0' }|.

      " Populate Header
      ls_hd-client          = sy-mandt.
      ls_hd-order_id        = lv_order_id.
      ls_hd-customer_id     = |CUST{ ( lv_index MOD 10 ) + 1 }|.
      ls_hd-overall_status  = COND #( WHEN lv_index MOD 2 = 0 THEN 'O' ELSE 'S' ).
      ls_hd-total_amount    = lv_index * CONV decfloat16( '150.50' ).
      ls_hd-currency_code   = 'USD'.
      ls_hd-created_by      = 'DEVELOPER'.

      GET TIME STAMP FIELD DATA(lv_ts).
      ls_hd-last_changed_at = lv_ts.

      APPEND ls_hd TO lt_hd.

      " Populate 3 Items per Header
      DO 3 TIMES.
        DATA(lv_item_idx) = sy-index.
        ls_it-client          = sy-mandt.
        ls_it-order_id        = lv_order_id.
        ls_it-item_position   = lv_item_idx * 10.
        ls_it-material_id     = |MAT-{ lv_item_idx * 100 }|.
        ls_it-quantity        = lv_item_idx * 2.
        ls_it-unit_of_measure = 'EA'.
        ls_it-item_amount     = lv_item_idx * CONV decfloat16( '50.17' ).
        ls_it-currency_code   = 'USD'.
        APPEND ls_it TO lt_it.
      ENDDO.
    ENDDO.

    " Insert fresh records into database tables
    INSERT ztab_o2c_hd FROM TABLE @lt_hd.
    INSERT ztab_o2c_it FROM TABLE @lt_it.

    IF sy-subrc = 0.
      COMMIT WORK.
      out->write( 'Successfully cleared old data and generated 100 Header records with 300 Item records!' ).
    ELSE.
      ROLLBACK WORK.
      out->write( 'Error during data generation. Check table definitions.' ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
