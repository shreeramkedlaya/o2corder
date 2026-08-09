@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_O2C_STATUS_VH
  as select from ztab_o2c_hd
{
      @UI.hidden: true
  key overall_status as Status,

      @EndUserText.label: 'Status'
      @UI.lineItem: [{ position: 10 }]
      case overall_status
          when 'O' then 'Open'
          when 'S' then 'Shipped'
          when 'C' then 'Cancelled'
          else 'Unknown'
      end            as StatusText
}
group by
  overall_status
