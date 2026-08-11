@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Master Interface View'
define view entity ZI_O2C_MATERIAL
  as select from ztab_o2c_mat
{
  key material_id,
      material_desc,
      @Semantics.amount.currencyCode: 'currency'
      unit_price,
      currency,
      @Semantics.quantity.unitOfMeasure: 'unit_of_measure'
      stock_quantity,
      unit_of_measure,
      material_group
}
