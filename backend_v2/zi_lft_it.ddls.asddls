@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Project Order Items'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_lft_it
  as select from ZTAB_LFT_IT
  association to parent zi_lft_hd    as _Header on $projection.OrderId = _Header.OrderId
  composition [0..*] of zi_lft_bplan as _BillingPlan
{
  key order_id    as OrderId,
  key item_pos    as ItemPos,
      material_id as MaterialId,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      quantity    as Quantity,
      uom         as Uom,
      @Semantics.amount.currencyCode: 'Currency'
      item_amount as ItemAmount,
      tax_rate    as TaxRate,
      @Semantics.amount.currencyCode: 'Currency'
      tax_amount  as TaxAmount,
      currency    as Currency,

      /* Associations */
      _Header,
      _BillingPlan
}
