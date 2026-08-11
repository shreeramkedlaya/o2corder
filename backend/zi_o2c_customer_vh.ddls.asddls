@EndUserText.label: 'Customer Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_O2C_CUSTOMER_VH
  as select from ztab_o2c_cust
{
      @EndUserText.label: 'Customer ID'
  key customer_id   as CustomerId,

      @EndUserText.label: 'Customer Name'
      customer_name as CustomerName,

      @EndUserText.label: 'City'
      city          as City,

      @EndUserText.label: 'Credit Limit'
      @Semantics.amount.currencyCode: 'Currency'
      credit_limit  as CreditLimit,

      @EndUserText.label: 'Payment Terms'
      payment_terms as PaymentTerms,

      @UI.hidden: true
      currency      as Currency
}
