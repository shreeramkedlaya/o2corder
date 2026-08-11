CLASS zcl_seed_o2c_master DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_seed_o2c_master IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " --- CUSTOMER MASTER ---
    DELETE FROM ztab_o2c_cust.

    DATA lt_cust TYPE TABLE OF ztab_o2c_cust.
    lt_cust = VALUE #(
      ( client = sy-mandt  customer_id = 'CUST-001'  customer_name = 'Acme Corporation'
        city = 'New York'  country = 'US'  credit_limit = '50000'
        credit_exposure = '12000'  payment_terms = 'NT30'  currency = 'USD' )
      ( client = sy-mandt  customer_id = 'CUST-002'  customer_name = 'GlobalTech Ltd'
        city = 'London'    country = 'GB'  credit_limit = '80000'
        credit_exposure = '5000'   payment_terms = 'NT60'  currency = 'USD' )
      ( client = sy-mandt  customer_id = 'CUST-003'  customer_name = 'SkyBridge Inc'
        city = 'Chicago'   country = 'US'  credit_limit = '30000'
        credit_exposure = '29500'  payment_terms = 'NT30'  currency = 'USD' )
    ).
    INSERT ztab_o2c_cust FROM TABLE @lt_cust.

    " --- MATERIAL MASTER ---
    DELETE FROM ztab_o2c_mat.

    DATA lt_mat TYPE TABLE OF ztab_o2c_mat.
    lt_mat = VALUE #(
      ( client = sy-mandt  material_id = 'MAT-100'  material_desc = 'Standard Widget'
        unit_price = '150.00'  currency = 'USD'  stock_quantity = '500'
        unit_of_measure = 'EA'  material_group = 'WIDGETS' )
      ( client = sy-mandt  material_id = 'MAT-200'  material_desc = 'Premium Gadget'
        unit_price = '300.00'  currency = 'USD'  stock_quantity = '200'
        unit_of_measure = 'EA'  material_group = 'GADGETS' )
      ( client = sy-mandt  material_id = 'MAT-300'  material_desc = 'Enterprise Module'
        unit_price = '450.00'  currency = 'USD'  stock_quantity = '100'
        unit_of_measure = 'EA'  material_group = 'SOFTWARE' )
    ).
    INSERT ztab_o2c_mat FROM TABLE @lt_mat.

    COMMIT WORK.
    out->write( 'Master data seeded successfully into ZTAB_O2C_CUST and ZTAB_O2C_MAT.' ).
  ENDMETHOD.
ENDCLASS.
