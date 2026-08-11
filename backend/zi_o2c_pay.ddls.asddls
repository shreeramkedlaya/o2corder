@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment Interface View'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_O2C_PAY
  as select from ztab_o2c_pay as pay
  association to ZI_O2C_INV_HD as _Invoice on $projection.invoice_id = _Invoice.invoice_id
{
  key pay.payment_id,
      pay.invoice_id,
      pay.order_id,
      pay.customer_id,
      pay.payment_date,
      @Semantics.amount.currencyCode: 'currency_code'
      pay.payment_amount,
      pay.currency_code,
      pay.payment_method,
      pay.reference,
      pay.created_by,
      pay.created_at,
      _Invoice
}
