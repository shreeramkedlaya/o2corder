@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Invoice Header Interface View'
define root view entity ZI_O2C_INV_HD
  as select from ztab_o2c_inv_hd as inv

  //  Hook it back up to the rest of the O2C chain!
  association        to ZI_O2C_HD     as _Order    on $projection.order_id = _Order.order_id
  association        to ZI_O2C_DEL_HD as _Delivery on $projection.delivery_id = _Delivery.delivery_id
  association [0..*] to ZI_O2C_PAY    as _Payments on $projection.invoice_id = _Payments.invoice_id
{
  key inv.invoice_id,
      inv.order_id,
      inv.delivery_id,
      inv.customer_id,
      inv.invoice_date,
      inv.due_date,

      @Semantics.amount.currencyCode: 'currency_code'
      inv.gross_amount,

      @Semantics.amount.currencyCode: 'currency_code'
      inv.paid_amount,

      @Semantics.amount.currencyCode: 'currency_code'
      inv.outstanding_amount,

      inv.currency_code,
      inv.ar_status,

      // Dynamically calculate the text description for the Fiori UI
      cast( case inv.ar_status
        when 'O' then 'Open'
        when 'P' then 'Partially Paid'
        when 'C' then 'Cleared'
        else 'Unknown'
      end as abap.char( 20 )) as ar_status_text,

      // 3=Green, 2=Yellow, 1=Red
      case inv.ar_status
        when 'C' then 3
        when 'P' then 2
        when 'O' then 1
        else 0
      end                     as ar_status_criticality,

      inv.payment_terms,
      inv.created_by,
      inv.last_changed_at,

      _Order,
      _Delivery,
      _Payments
}
