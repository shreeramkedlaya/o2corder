@EndUserText.label: 'Sales Order Item Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: false

@UI.headerInfo: {
  typeName: 'Order Item',
  typeNamePlural: 'Order Items',
  title: { type: #STANDARD, value: 'item_position' },
  description: { type: #STANDARD, value: 'material_id' }
}

define view entity ZC_O2C_IT
  as projection on ZI_O2C_IT
{
      @UI.facet: [
        {
          id: 'ItemDetails',
          type: #COLLECTION,
          label: 'Item Details',
          position: 10
        },
        {
          id: 'ItemForm',
          type: #FIELDGROUP_REFERENCE,
          parentId: 'ItemDetails',
          label: 'General Information',
          position: 10,
          targetQualifier: 'ItemGQ'
        }
      ]

      @EndUserText.label: 'Order ID'
  key order_id,

      @EndUserText.label: 'Item Position'
      @UI.lineItem: [{ position: 10 }]
      @UI.fieldGroup: [{ position: 10, qualifier: 'ItemGQ' }]
  key item_position,

      @EndUserText.label: 'Material ID'
      @UI.lineItem: [{ position: 20 }]
      @UI.fieldGroup: [{ position: 20, qualifier: 'ItemGQ' }]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_O2C_MATERIAL_VH', element: 'MaterialId' } }]
      material_id,

      @EndUserText.label: 'Quantity'
      @Semantics.quantity.unitOfMeasure: 'unit_of_measure'
      @UI.lineItem: [{ position: 30 }]
      @UI.fieldGroup: [{ position: 30, qualifier: 'ItemGQ' }]
      quantity,

      @EndUserText.label: 'Unit of Measure'
      unit_of_measure,

      @EndUserText.label: 'Item Amount'
      @Semantics.amount.currencyCode: 'currency_code'
      @UI.lineItem: [{ position: 40 }]
      @UI.fieldGroup: [{ position: 40, qualifier: 'ItemGQ' }]
      item_amount,

      @EndUserText.label: 'Currency'
      currency_code,

      _Header : redirected to parent ZC_O2C_HD
}
