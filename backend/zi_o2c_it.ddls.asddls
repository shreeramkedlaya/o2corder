@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item Interface View'
define view entity ZI_O2C_IT
  as select from ztab_o2c_it
  association to parent ZI_O2C_HD as _Header on $projection.order_id = _Header.order_id
{
  key order_id,
  key item_position,
      material_id,
      @Semantics.quantity.unitOfMeasure: 'unit_of_measure'
      quantity,
      unit_of_measure,
      @Semantics.amount.currencyCode: 'currency_code'
      item_amount,
      currency_code,

      _Header
}
