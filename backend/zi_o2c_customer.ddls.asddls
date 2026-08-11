@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Customer Master Interface View'
define view entity ZI_O2C_CUSTOMER
  as select from ztab_o2c_cust
{
  key customer_id,
      customer_name,
      city,
      country,
      @Semantics.amount.currencyCode: 'currency'
      credit_limit,
      @Semantics.amount.currencyCode: 'currency'
      credit_exposure,
      payment_terms,
      currency,
      @Semantics.amount.currencyCode: 'currency'
      ( credit_limit - credit_exposure ) as available_credit
}
