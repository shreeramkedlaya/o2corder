@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Header Interface View Entity'
define root view entity ZI_O2C_HD
  as select from    ztab_o2c_hd   as hd

  -- new: join cust master to get the name
    left outer join ztab_o2c_cust as cust on hd.customer_id = cust.customer_id
  association [0..*] to ZI_O2C_DEL_HD as _Delivery on $projection.order_id = _Delivery.order_id
  association [0..*] to ZI_O2C_INV_HD as _Invoice  on $projection.order_id = _Invoice.order_id
  composition [0..*] of ZI_O2C_IT     as _Items
{
  key hd.order_id,
      hd.customer_id,

      -- new: pulled from customer master
      cust.customer_name,

      -- new: added temporal and payment fields
      hd.order_date,
      hd.requested_delivery_date,
      hd.payment_terms,
      hd.credit_check_status,

      hd.overall_status,

      // --- Add the status text calculation here ---
      cast( case hd.overall_status
       when 'D' then 'Draft'
        when 'O' then 'Open'
        when 'F' then 'In Fulfilment'
        when 'S' then 'Shipped'
        when 'I' then 'Invoiced'
        when 'P' then 'Paid / Closed'
        when 'C' then 'Cancelled'
        else 'Unknown'
      end as abap.char( 20 )) as overall_status_text,

      -- text generation for credit status
      cast( case hd.credit_check_status
      when 'P' then 'Credit OK'
      when 'F' then 'Credit Blocked'
      when 'R' then 'Manually Released'
      else 'Not Checked'
      end as abap.char( 25 )) as credit_check_status_text,

      -- UI Colors for Credit Status
      case hd.credit_check_status
        when 'P' then 3 -- green
        when 'R' then 2 -- yellow
        when 'F' then 1 -- red
        else 0
      end                     as credit_check_criticality,

      case hd.overall_status
       when 'S' then 3 // 3=green
       when 'O' then 2 // 2=yellow
       when 'C' then 1 // 1=red
        else 0
      end                     as overall_status_criticality,
      @Semantics.amount.currencyCode: 'currency_code'
      hd.total_amount,
      hd.currency_code,
      hd.created_by,
      hd.last_changed_at,

      _Items,
      _Delivery,
      _Invoice
}
