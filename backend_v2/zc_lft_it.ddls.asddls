@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection view for Project Order Items'

@UI: {
    headerInfo : {
        typeName: 'Item',
        typeNamePlural: 'Items',
        title:{
            type: #STANDARD,
            value: 'ItemPos'
        }
    }
}

define view entity ZC_LFT_IT
  as projection on zi_lft_it
{
      @UI.facet: [{
            id: 'ItemDetails',
            purpose: #STANDARD,
            type: #IDENTIFICATION_REFERENCE,
            label: 'Item Details',
            position: 10
           },
           {
            id: 'BillingPlan',
            purpose: #STANDARD,
            type: #LINEITEM_REFERENCE,
            label: 'Billing Plan / Milestone',
            position: 20,
            targetElement: '_BillingPlan'
           }
      ]

      @UI.lineItem: [{ position: 10 }]
  key OrderId,

      @UI.lineItem: [{ position: 20 }]
      @UI.identification: [{ position: 10 }]
  key ItemPos,

      @UI.lineItem: [{ position: 30 }]
      @UI.identification: [{ position: 20 }]
      MaterialId,

      @UI.lineItem: [{ position: 40 }]
      @UI.identification: [{ position: 30 }]
      Quantity,
      Uom,

      @UI.lineItem: [{ position: 50 }]
      @UI.identification: [{ position: 40 }]
      ItemAmount,


      TaxRate,
      TaxAmount,
      Currency,

      /* Associations */
      _BillingPlan : redirected to composition child ZC_LFT_BPLAN,
      _Header      : redirected to parent ZC_LFT_HD
}
