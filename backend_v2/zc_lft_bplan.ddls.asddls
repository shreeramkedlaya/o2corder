@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Billing Milestones'

@UI: {
    headerInfo: {
        typeName: 'Milestone',
        typeNamePlural: 'Milestones',
        title: {
            type: #STANDARD,
            value: 'MilestoneId'
        }
    }
}
define view entity ZC_LFT_BPLAN
  as projection on ZI_LFT_BPLAN
{
      @UI.facet: [{
          id: 'MilestoneDetails',
          purpose: #STANDARD,
          type: #IDENTIFICATION_REFERENCE,
          label: 'Milestone Details',
          position: 10 }]
  key OrderId,
  key ItemPos,

      @UI.lineItem: [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
      @EndUserText.label: 'Milestone ID'
  key MilestoneId,
      @UI.lineItem: [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      @EndUserText.label: 'Milestone Type'
      MilestoneType,
      @UI.lineItem: [{ position: 30 }]
      @UI.identification: [{ position: 30 }]
      @EndUserText.label: 'Phase ID'
      PhaseId,

      @UI.lineItem: [{ position: 40 }]
      @UI.identification: [{ position: 40 }]
      @EndUserText.label: 'Percentage (%)'
      Percentage,

      @UI.lineItem: [{ position: 50 }]
      @UI.identification: [{ position: 50 }]
      @EndUserText.label: 'Amount'
      Amount,

      @EndUserText.label: 'Currency'
      Currency,

      @UI.lineItem: [{ position: 60 }]
      @UI.identification: [{ position: 60 }]
      @EndUserText.label: 'Status'
      Status,

      @UI.lineItem: [
        {position: 70},
        {type: #FOR_ACTION, dataAction: 'generateInvoice', label: 'Raise Invoice'}

      ]
      @UI.identification: [{ position: 70 }]
      @EndUserText.label: 'Invoice ID'
      InvoiceId,

      @UI.lineItem: [{ position: 80 }]
      @UI.identification: [{ position: 80 }]
      DueDate,


      /* Associations */
      _Item   : redirected to parent ZC_LFT_IT,
      _Header : redirected to ZC_LFT_HD
}
