@EndUserText.label: 'Material Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_O2C_MATERIAL_VH
  as select from ztab_o2c_it
{
      @UI.lineItem: [{ position: 10,label: 'Material ID'}]
  key material_id                 as MaterialId,

      @UI.lineItem: [{ position: 20,label: 'Standard Price'}]
      @Semantics.amount.currencyCode: 'Currency'
      cast( case material_id
      when 'MAT-100' then 150.00
      when 'MAT-200' then 300.00
      when 'MAT-300' then 450.00
      else 50.00
      end as abap.curr( 15, 2 ) ) as Price,

      @UI.hidden: true
      cast('USD' as abap.cuky )   as Currency
}
group by
  material_id
