CLASS zcl_lft_mock_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_lft_mock_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " Use EML to create an Item for our existing Order!
    " This will automatically trigger your generateMilestones determination!
    MODIFY ENTITIES OF zi_lft_hd
      ENTITY OrderHeader
      CREATE BY \_Item
      FIELDS ( ItemPos ItemAmount Currency )
      WITH VALUE #( ( OrderId = '1000000001'
                      %target = VALUE #( (
                        %cid = 'ITEM1'
                        ItemPos = '0010'
                        ItemAmount = 100000
                        Currency = 'USD'
                        %control = VALUE #( ItemPos = if_abap_behv=>mk-on
                                            ItemAmount = if_abap_behv=>mk-on
                                            Currency = if_abap_behv=>mk-on )
                      ) ) ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES.

    out->write( 'Item created via RAP! Check your Fiori App!' ).
  ENDMETHOD.
ENDCLASS.

