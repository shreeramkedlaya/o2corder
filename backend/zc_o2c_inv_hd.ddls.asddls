@EndUserText.label: 'Invoice Header Consumption View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_O2C_INV_HD
  provider contract transactional_query
  as projection on ZI_O2C_INV_HD
  association [0..*] to ZC_O2C_PAY as _Payments on $projection.invoice_id = _Payments.invoice_id
{
      @UI.facet: [
        {
          id: 'InvoiceInfo',
          type: #IDENTIFICATION_REFERENCE,
          label: 'Invoice Details',
          position: 10
        },
        {
          id: 'Payment',
          purpose: #STANDARD,
          type: #LINEITEM_REFERENCE,
          label: 'Payment History',
          position: 20,
          targetElement: '_Payments'
        }
      ]

      @UI.lineItem: [
        { position: 10 },
        { type: #FOR_ACTION, dataAction: 'postPayment', label: 'Post Payment'}
        ]
      @UI.identification: [
        { position: 10 },
        { type: #FOR_ACTION, dataAction: 'postPayment', label: 'Post Payment'}
        ]
  key invoice_id,

      @UI.lineItem: [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      order_id,

      @UI.lineItem: [{ position: 30 }]
      @UI.identification: [{ position: 30 }]
      delivery_id,

      @UI.lineItem: [{ position: 40 }]
      @UI.identification: [{ position: 40 }]
      customer_id,

      @UI.lineItem: [{ position: 50 }]
      @UI.identification: [{ position: 50 }]
      invoice_date,

      @UI.lineItem: [{ position: 60 }]
      @UI.identification: [{ position: 60 }]
      due_date,

      @UI.lineItem: [{ position: 70 }]
      @UI.identification: [{ position: 70 }]
      gross_amount,

      @UI.lineItem: [{ position: 80 }]
      @UI.identification: [{ position: 80 }]
      paid_amount,

      @UI.lineItem: [{ position: 90 }]
      @UI.identification: [{ position: 90 }]
      @UI.dataPoint: { title: 'Outstanding Amount', criticality: 'ar_status_criticality' }
      outstanding_amount,

      currency_code,

      @UI.lineItem: [{ position: 100, criticality: 'ar_status_criticality', label: 'Status' }]
      @UI.identification: [{ position: 100, criticality: 'ar_status_criticality', label: 'Status' }]
      ar_status_text,

      @UI.hidden: true
      ar_status,

      @UI.hidden: true
      ar_status_criticality,

      @UI.identification: [{ position: 110 }]
      payment_terms,

      @UI.hidden: true
      created_by,

      @UI.hidden: true
      last_changed_at,

      /* Associations */
      _Order,
      _Delivery,
      _Payments
}
