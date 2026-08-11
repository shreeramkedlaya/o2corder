@EndUserText.label: 'Payment Input Parameter'
define abstract entity ZINV_PAYMENT_INPUT
{
  @Semantics.amount.currencyCode: 'currency_code'
  payment_amount : abap.curr(15,2);
  currency_code  : abap.cuky;

  @EndUserText.label: 'Payment Method (BANK/CARD)'
  payment_method : abap.char(10);

  @EndUserText.label: 'Reference / Cheque Number'
  reference      : abap.char(30);
}
