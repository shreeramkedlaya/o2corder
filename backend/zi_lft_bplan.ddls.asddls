@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Billing Plan'
define view entity ZI_LFT_BPLAN
  as select from ztab_lft_bplan
  association        to parent zi_lft_it as _Item   on  $projection.OrderId = _Item.OrderId
                                                    and $projection.ItemPos = _Item.ItemPos


  association [1..1] to ZI_LFT_HD        as _Header on  $projection.OrderId = _Header.OrderId
{
  key order_id       as OrderId,
  key item_pos       as ItemPos,
  key milestone_id   as MilestoneId,
      milestone_type as MilestoneType,
      phase_id       as PhaseId,
      percentage     as Percentage,
      @Semantics.amount.currencyCode: 'Currency'
      amount         as Amount,
      currency       as Currency,
      status         as Status,
      invoice_id     as InvoiceId,
      due_date       as DueDate,

      /* Associations */
      _Item,
      _Header
}
