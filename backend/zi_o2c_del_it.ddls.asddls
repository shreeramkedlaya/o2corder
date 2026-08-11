@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery Items Interface View'
define view entity ZI_O2C_DEL_IT
  as select from ztab_o2c_del_it

  association to parent ZI_O2C_DEL_HD as _DeliveryHeader on $projection.delivery_id = _DeliveryHeader.delivery_id
{
  key delivery_id,
  key delivery_item,
      order_item_position,
      material_id,

      @Semantics.quantity.unitOfMeasure: 'unit_of_measure'
      quantity_ordered,

      @Semantics.quantity.unitOfMeasure: 'unit_of_measure'
      quantity_delivered,

      unit_of_measure,

      _DeliveryHeader
}
