@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Project Order Header'
@UI: {
  headerInfo: { typeName: 'Project Order', typeNamePlural: 'Project Orders', title: { type: #STANDARD, value: 'OrderId' } }
}
define root view entity ZC_LFT_HD
  as projection on ZI_LFT_HD
{
      @UI.facet: [ { id: 'OrderDetails', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Order Details', position: 10 },
                   { id: 'Items', purpose: #STANDARD, type: #LINEITEM_REFERENCE, label: 'Items', position: 20, targetElement: '_Item' } ]

      @UI.lineItem: [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
  key OrderId,

      @UI.lineItem: [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      CustomerId,

      @UI.lineItem: [{ position: 30 }]
      @UI.identification: [{ position: 30 }]
      GrossTotal,

      @UI.identification: [{ position: 40 }]
      TaxTotal,
      Currency,

      @UI.lineItem: [{ position: 40 }]
      @UI.identification: [{ position: 50 }]
      Status,

      /* Associations */
      _Item : redirected to composition child ZC_LFT_IT
}
