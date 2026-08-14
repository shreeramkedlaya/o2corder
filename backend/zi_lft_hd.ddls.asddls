@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Project Order Header'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_LFT_HD
  as select from ZTAB_LFT_HD
  composition [0..*] of zi_lft_it as _Item
{
  key order_id    as OrderId,
      customer_id as CustomerId,
      @Semantics.amount.currencyCode: 'Currency'
      gross_total as GrossTotal,
      @Semantics.amount.currencyCode: 'Currency'
      tax_total   as TaxTotal,
      currency    as Currency,
      status      as Status,

      _Item
}
