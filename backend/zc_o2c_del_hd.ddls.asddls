@EndUserText.label: 'Delivery Header Consumption View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true

@UI: {
  headerInfo: {
    typeName: 'Delivery',
    typeNamePlural: 'Deliveries',
    title: { type: #STANDARD, value: 'delivery_id' },
    description: { type: #STANDARD, value: 'order_id' }
  }
}
define root view entity ZC_O2C_DEL_HD
  provider contract transactional_query
  as projection on ZI_O2C_DEL_HD
{
      @UI.facet: [
        {
          id: 'HeaderData',
          type: #COLLECTION,
          label: 'General Information',
          position: 10
        },
        {
          id: 'DeliveryInfo',
          type: #FIELDGROUP_REFERENCE,
          parentId: 'HeaderData',
          label: 'Delivery Details',
          position: 10,
          targetQualifier: 'GQ_DELIVERY'
        },
        {
          id: 'DeliveryItems',
          type: #LINEITEM_REFERENCE,
          label: 'Delivery Items',
          position: 20,
          targetElement: '_DeliveryItems'
        }
      ]

      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
  key delivery_id,

      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 20 }]
      @UI.selectionField: [{ position: 20 }]
      @UI.fieldGroup: [{ position: 10, qualifier: 'GQ_DELIVERY' }]
      order_id,

      @UI.lineItem: [{ position: 30 }]
      @UI.fieldGroup: [{ position: 20, qualifier: 'GQ_DELIVERY' }]
      customer_id,

      @UI.lineItem: [{ position: 40 }]
      @UI.fieldGroup: [{ position: 30, qualifier: 'GQ_DELIVERY' }]
      delivery_date,

      @UI.lineItem: [{ position: 50 }]
      @UI.fieldGroup: [{ position: 40, qualifier: 'GQ_DELIVERY' }]
      carrier,

      @UI.lineItem: [{ position: 60 }]
      @UI.fieldGroup: [{ position: 50, qualifier: 'GQ_DELIVERY' }]
      tracking_number,

      @UI.lineItem: [
      { position: 70, criticality: 'delivery_status_criticality' },
      { type: #FOR_ACTION, dataAction: 'postGoodsIssue', label: 'Post Goods Issue', requiresContext: true },
      { type: #FOR_ACTION, dataAction: 'createInvoice', label: 'Create Invoice', requiresContext: true }
      ]
      @UI.identification: [
        { type: #FOR_ACTION, dataAction: 'postGoodsIssue', label: 'Post Goods Issue', requiresContext: true },
        { type: #FOR_ACTION, dataAction: 'createInvoice', label: 'Create Invoice', requiresContext: true }
      ]
      @UI.fieldGroup: [{ position: 60, qualifier: 'GQ_DELIVERY' }]
      @UI.dataPoint: { qualifier: 'DeliveryStatusDP', title: 'Status' }
      @ObjectModel.text.element: ['delivery_status_text']
      delivery_status,


      @UI.hidden: true
      delivery_status_text,
      @UI.hidden: true
      delivery_status_criticality,

      @UI.fieldGroup: [{ position: 70, qualifier: 'GQ_DELIVERY' }]
      goods_issue_date,

      @UI.hidden: true
      currency_code,
      @UI.hidden: true
      created_by,
      @UI.hidden: true
      last_changed_at,

      /* Associations */
      _DeliveryItems : redirected to composition child ZC_O2C_DEL_IT,
      _Order         : redirected to ZC_O2C_HD
}
