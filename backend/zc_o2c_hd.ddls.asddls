@EndUserText.label: 'Sales Order Header Projection Contract'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
/* @Search.searchable: true */

@UI.headerInfo: {
  typeName: 'Sales Order',
  typeNamePlural: 'Sales Orders',
  title: { type: #STANDARD, value: 'order_id' },
  description: { type: #STANDARD, value: 'customer_id' }
}

@UI.selectionVariant: [
  {
    text: 'All Orders',
    qualifier: 'All'
  },
  {
    text: 'Open Orders',
    qualifier: 'Open',
    filter: 'overall_status EQ "O"'
  },
  {
    text: 'Shipped Orders',
    qualifier: 'Shipped',
    filter: 'overall_status EQ "S"'
  }
]

@UI.presentationVariant: [{
  sortOrder: [{
    by: 'order_id',
    direction: #DESC
   }]
 }]
define root view entity ZC_O2C_HD
  provider contract transactional_query
  as projection on ZI_O2C_HD
{


      @UI.facet: [
        // --- TOP HEADER KPI: Total Amount Badge ---
        {
          id: 'HeaderTotalAmount',
          purpose: #HEADER,
          type: #DATAPOINT_REFERENCE,
          targetQualifier: 'TotalAmountDP',
          position: 10
        },
        // --- TOP HEADER KPI: Overall Status Badge ---
        {
          id: 'HeaderStatus',
          purpose: #HEADER,
          type: #DATAPOINT_REFERENCE,
          targetQualifier: 'StatusDP',
          position: 20
        },

        // --- MAIN TAB 1: General Information ---
        {
          id: 'HeaderData',
          type: #COLLECTION,
          label: 'General Information',
          position: 10
        },
          {
            id: 'FieldGroup1',
            type: #FIELDGROUP_REFERENCE,
            parentId: 'HeaderData',
            label: 'Order Info',
            position: 10,
            targetQualifier: 'GQ1'
          },
          {
            id: 'FinancialGroup',
            type: #FIELDGROUP_REFERENCE,
            parentId: 'HeaderData',
            label: 'Financial Details',
            position: 20,
            targetQualifier: 'GQ2'
          },

        // --- MAIN TAB 2: Order Items Table ---
        {
          id: 'Items',
          type: #LINEITEM_REFERENCE,
          label: 'Order Items',
          position: 20,
          targetElement: '_Items'
        }
      ]

      // --- GENERAL INFORMATION FIELDS ---
      /* @Search.defaultSearchElement: true */
      @EndUserText.label: 'Order ID'
      @UI.lineItem: [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
      @UI.fieldGroup: [{ position: 10, qualifier: 'GQ1' }]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_O2C_HD', element: 'order_id' } }]
  key order_id,

      /* @Search.defaultSearchElement: true */
      @EndUserText.label: 'Customer ID'
      @UI.lineItem: [{ position: 20 }]
      @UI.selectionField: [{ position: 20 }]
      @UI.fieldGroup: [{ position: 20, qualifier: 'GQ1' }]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_O2C_CUSTOMER_VH', element: 'CustomerId' } }]

      customer_id,



      @Consumption.valueHelpDefinition: [{
      entity: { name: 'ZI_O2C_STATUS_VH', element: 'Status' }
      }]
      @ObjectModel.text.element: ['overall_status_text']
      @EndUserText.label: 'Overall Status'
      @UI.selectionField: [{ position: 30 }]
      @UI.lineItem: [
        { position: 30, criticality: 'overall_status_criticality' },
        { type: #FOR_ACTION, dataAction: 'shipOrder', label: 'Ship Order', requiresContext: true },
        { type: #FOR_ACTION, dataAction: 'cancelOrder', label: 'Cancel Order', requiresContext: true }
      ]
      @UI.identification: [
        { type: #FOR_ACTION, dataAction: 'shipOrder', label: 'Ship Order', requiresContext: true },
        { type: #FOR_ACTION, dataAction: 'cancelOrder', label: 'Cancel Order', requiresContext: true }
      ]
      @UI.fieldGroup: [{ position: 30, qualifier: 'GQ1' }]
      @UI.dataPoint: { qualifier: 'StatusDP', title: 'Order Status' }
      overall_status,

      @UI.hidden: true
      overall_status_text,
      @UI.hidden: true
      overall_status_criticality,

      @EndUserText.label: 'Total Amount'
      @Semantics.amount.currencyCode: 'currency_code'
      @UI.lineItem: [{ position: 40 }]
      @UI.fieldGroup: [{ position: 10, qualifier: 'GQ2' }]
      @UI.dataPoint: { qualifier: 'TotalAmountDP', title: 'Total Value' }
      total_amount,

      @UI.hidden: true
      currency_code,
      /* @EndUserText.label: 'Currency'
      @UI.fieldGroup: [{ position: 20, qualifier: 'GQ2' }]
      currency_code, */

      // --- ADMINISTRATIVE FIELDS ---
      @UI.hidden: true
      created_by,

      @UI.hidden: true
      last_changed_at,

      // --- COMPOSITION CHILD LINK ---
      _Items : redirected to composition child ZC_O2C_IT
}
