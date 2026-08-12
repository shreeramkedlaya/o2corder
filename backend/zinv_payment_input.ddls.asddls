@EndUserText.label: 'Payment Input Parameter'
define abstract entity ZINV_PAYMENT_INPUT
{
  @Semantics.amount.currencyCode: 'currency_code'
  payment_amount : abap.curr(15,2);

  // CHANGED THIS LINE!
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_O2C_CURRENCY_VH', element: 'CurrencyCode'} }]
  currency_code  : abap.cuky;

  @EndUserText.label: 'Payment Method (BANK/CARD)'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_O2C_PAYMETH_VH', element: 'PaymentMethod'} }]
  payment_method : abap.char(10);

  @EndUserText.label: 'Reference / Cheque Number'
  reference      : abap.char(30);
}
