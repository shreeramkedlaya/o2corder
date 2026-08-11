@EndUserText.label: 'Payment Consumption View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_O2C_PAY
  provider contract transactional_query
  as projection on ZI_O2C_PAY

{
      @UI.facet: [
          {
              id: 'PaymentInfo',
              type: #IDENTIFICATION_REFERENCE,
              label: 'Payment Details',
              position: 10

          }
       ]
      @UI.lineItem: [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
  key payment_id,
      @UI.lineItem: [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      invoice_id,

      @UI.hidden: true
      order_id,

      @UI.hidden: true
      customer_id,

      @UI.lineItem: [{ position: 30 }]
      @UI.identification: [{ position: 30 }]
      payment_date,

      @UI.lineItem: [{ position: 40 }]
      @UI.identification: [{ position: 40 }]
      payment_amount,

      currency_code,

      @UI.lineItem: [{position: 50}]
      @UI.identification: [{ position: 50 }]
      payment_method,

      @UI.lineItem: [{ position: 60 }]
      @UI.identification: [{ position: 60 }]
      reference,

      @UI.hidden: true
      created_by,

      @UI.hidden: true
      created_at,

      /* Associations */
      _Invoice

}
