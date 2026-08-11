CLASS zbp_i_o2c_del_hd DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_o2c_del_hd.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_stock_update,
             material_id TYPE ztab_o2c_del_it-material_id,
             quantity    TYPE ztab_o2c_del_it-quantity_delivered,
           END OF ty_stock_update.

    " Global memory to pass data from the Action phase to the Save phase
    CLASS-DATA: gt_stock_updates TYPE TABLE OF ty_stock_update.


    TYPES: BEGIN OF ty_credit_update,
             customer_id TYPE ztab_o2c_del_hd-customer_id,
             amount      TYPE ztab_o2c_inv_hd-gross_amount,
           END OF ty_credit_update.

    TYPES: BEGIN OF ty_status_update,
             order_id TYPE ztab_o2c_hd-order_id,
             status   TYPE ztab_o2c_hd-overall_status,
           END OF ty_status_update.

    CLASS-DATA: gt_status_updates TYPE TABLE OF ty_status_update.


    " Global memory for Phase 4
    CLASS-DATA: gt_credit_updates TYPE TABLE OF ty_credit_update.

ENDCLASS.

CLASS zbp_i_o2c_del_hd IMPLEMENTATION.
ENDCLASS.


