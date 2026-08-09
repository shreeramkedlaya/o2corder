@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Unit of Measure Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_O2C_UOM_VH
  as select from ztab_o2c_it
{
      @UI.lineItem: [{ position: 10 }]
  key unit_of_measure as Unit
}

group by
  unit_of_measure
