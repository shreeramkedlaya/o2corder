@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Header Interface View Entity'
define root view entity ZI_O2C_HD
  as select from ztab_o2c_hd
  composition [0..*] of ZI_O2C_IT as _Items
{
  key order_id,
      customer_id,
      overall_status,

      // --- Add the status text calculation here ---
      cast( case overall_status
        when 'O' then 'Open'
        when 'S' then 'Shipped'
        when 'C' then 'Cancelled'
        else 'Unknown'
      end as abap.char( 20 )) as overall_status_text,
      case overall_status
       when 'S' then 3 // 3=green
       when 'O' then 2 // 2=yellow
       when 'C' then 1 // 1=red
        else 0
      end                     as overall_status_criticality,
      @Semantics.amount.currencyCode: 'currency_code'
      total_amount,
      currency_code,
      created_by,
      last_changed_at,

      _Items
}
