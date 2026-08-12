@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment Method Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_O2C_PAYMETH_VH
  as select distinct from ztab_o2c_hd
{
  key cast( 'BANK' as abap.char( 10 ) ) as PaymentMethod
}
where
  order_id is not initial

union all

select distinct from ztab_o2c_hd
{
  key cast( 'CARD' as abap.char( 10 ) ) as PaymentMethod
}
where
  order_id is not initial
