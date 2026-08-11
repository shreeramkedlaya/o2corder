@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery Header Interface View'
define root view entity ZI_O2C_DEL_HD
  as select from ztab_o2c_del_hd as del

  association [1..1] to ZI_O2C_HD     as _Order on $projection.order_id = _Order.order_id

  composition [0..*] of ZI_O2C_DEL_IT as _DeliveryItems
{
  key del.delivery_id,
      del.order_id,
      del.customer_id,
      del.delivery_date,
      del.carrier,
      del.tracking_number,
      del.delivery_status,

      cast( case del.delivery_status
        when 'P' then 'Pending'
        when 'G' then 'Goods Issued'
        when 'D' then 'Delivered'
        else 'Unknown'
      end as abap.char( 20 )) as delivery_status_text,

      case del.delivery_status
        when 'G' then 3  // green
        when 'D' then 3  // green
        when 'P' then 2  // yellow
        else 0
      end                     as delivery_status_criticality,

      del.goods_issue_date,
      del.currency_code,
      del.created_by,
      del.last_changed_at,

      _Order,
      _DeliveryItems
}
