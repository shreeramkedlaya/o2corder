@EndUserText.label: 'Delivery Items Consumption View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@UI: {
  headerInfo: {
    typeName: 'Delivery Item',
    typeNamePlural: 'Delivery Items',
    title: { type: #STANDARD, value: 'delivery_item' }
  }
}
define view entity ZC_O2C_DEL_IT
  as projection on ZI_O2C_DEL_IT
{
      @UI.facet: [
        {
          id: 'ItemInfo',
          type: #IDENTIFICATION_REFERENCE,
          label: 'Item Details',
          position: 10
        }
      ]

      @UI.hidden: true
  key delivery_id,

      @EndUserText.label: 'Item No.'
      @UI.lineItem: [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
  key delivery_item,

      @EndUserText.label: 'Sales Order Item'
      @UI.lineItem: [{ position: 30 }]
      @UI.identification: [{ position: 30 }]
      order_item_position,

      @EndUserText.label: 'Material'
      @UI.lineItem: [{ position: 40 }]
      @UI.identification: [{ position: 40 }]
      material_id,

      @EndUserText.label: 'Quantity Ordered'
      @UI.lineItem: [{ position: 50 }]
      @UI.identification: [{ position: 50 }]
      quantity_ordered,

      @EndUserText.label: 'Quantity Delivered'
      @UI.lineItem: [{ position: 60 }]
      @UI.identification: [{ position: 60 }]
      quantity_delivered,


      @UI.hidden: true
      unit_of_measure,

      /* Associations */
      _DeliveryHeader : redirected to parent ZC_O2C_DEL_HD
}
