@EndUserText.label: 'Customer Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_O2C_CUSTOMER_VH
  as select from ztab_o2c_hd
{
      @UI.lineItem: [{ position: 10 }]
  key customer_id as CustomerId
}
group by
  customer_id
