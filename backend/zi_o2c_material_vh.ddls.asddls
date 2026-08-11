@EndUserText.label: 'Material Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_O2C_MATERIAL_VH
  as select from ztab_o2c_mat
{
      @UI.lineItem: [{ position: 10 }]
      @EndUserText.label: 'Material ID'
  key material_id     as MaterialId,

      @UI.lineItem: [{ position: 15 }]
      @EndUserText.label: 'Description'
      material_desc   as MaterialDescription,

      @UI.lineItem: [{ position: 20 }]
      @EndUserText.label: 'Standard Price'
      @Semantics.amount.currencyCode: 'Currency'
      unit_price      as Price,

      @UI.hidden: true
      currency        as Currency,

      @UI.lineItem: [{ position: 30 }]
      @EndUserText.label: 'Available Stock'
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      stock_quantity  as StockQuantity,

      @UI.hidden: true
      unit_of_measure as UnitOfMeasure
}
