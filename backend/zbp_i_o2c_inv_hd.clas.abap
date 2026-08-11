CLASS zbp_i_o2c_inv_hd DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_o2c_inv_hd.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_payment_insert,
             payment_id     TYPE ztab_o2c_pay-payment_id,
             invoice_id     TYPE ztab_o2c_pay-invoice_id,
             order_id       TYPE ztab_o2c_pay-order_id,
             customer_id    TYPE ztab_o2c_pay-customer_id,
             payment_date   TYPE ztab_o2c_pay-payment_date,
             payment_amount TYPE ztab_o2c_pay-payment_amount,
             currency_code  TYPE ztab_o2c_pay-currency_code,
             payment_method TYPE ztab_o2c_pay-payment_method,
             reference      TYPE ztab_o2c_pay-reference,
           END OF ty_payment_insert.

    TYPES: BEGIN OF ty_credit_update,
             customer_id TYPE ztab_o2c_cust-customer_id,
             amount      TYPE ztab_o2c_inv_hd-gross_amount,
           END OF ty_credit_update.

    TYPES: BEGIN OF ty_status_update,
             order_id TYPE ztab_o2c_hd-order_id,
             status   TYPE ztab_o2c_hd-overall_status,
           END OF ty_status_update.

    CLASS-DATA: gt_payments       TYPE TABLE OF ty_payment_insert,
                gt_credit_updates TYPE TABLE OF ty_credit_update,
                gt_status_updates TYPE TABLE OF ty_status_update.
ENDCLASS.

CLASS zbp_i_o2c_inv_hd IMPLEMENTATION.
ENDCLASS.

