## Phase 6 — UI & Dashboard Analytics

**Goal:** Make the full document chain navigable and build a pipeline KPI dashboard.

---

### Step 6.1 — Complete Order Status Lifecycle

Update `ZI_O2C_HD` CDS CASE expressions, `ZI_O2C_STATUS_VH`, and `ZI_O2C_HD` BDEF to cover all 7 status values:

| Code | Text | Criticality | Stage Triggered |
|------|------|-------------|-----------------|
| `D` | Draft | 0 (grey) | Order created as draft |
| `O` | Open | 2 (yellow) | Order activated/saved |
| `F` | In Fulfilment | 2 (yellow) | `createDelivery` called |
| `S` | Shipped | 3 (green) | `postGoodsIssue` called |
| `I` | Invoiced | 2 (yellow) | `createInvoice` called |
| `P` | Paid / Closed | 3 (green) | `postPayment` clears invoice |
| `C` | Cancelled | 1 (red) | `cancelOrder` called |

---

### Step 6.2 — Document Flow Navigation

**Option A (Simple — Field links):** On `ZC_O2C_HD`, add denormalized `delivery_id` and `invoice_id` fields with `@Consumption.semanticObject` pointing to their respective apps. This renders as a clickable link in the Object Page.

**Option B (Rich — `@UI.fieldGroup` Document Flow section):** Create a dedicated FieldGroup facet labelled "Document Flow" on the Order Object Page:

```abap
" Add to ZI_O2C_HD CDS:
association [0..1] to ZI_O2C_DEL_HD as _Delivery  on ... order_id = _Delivery.order_id
association [0..1] to ZI_O2C_INV_HD as _Invoice   on ... order_id = _Invoice.order_id

" In ZC_O2C_HD @UI.facet array:
{
  id: 'DocumentFlow',
  type: #COLLECTION,
  label: 'Document Flow',
  position: 50
},
{
  id: 'DocFlowFields',
  type: #FIELDGROUP_REFERENCE,
  parentId: 'DocumentFlow',
  label: 'Document References',
  position: 10,
  targetQualifier: 'DocFlow'
},

" Annotate the link fields:
@EndUserText.label: 'Delivery Document'
@Consumption.semanticObject: 'ZC_O2C_DEL_HD'
@Consumption.semanticObjectAction: 'display'
@UI.fieldGroup: [{ position: 10, qualifier: 'DocFlow' }]
delivery_id,  " pulled via _Delivery association

@EndUserText.label: 'Invoice Document'
@Consumption.semanticObject: 'ZC_O2C_INV_HD'
@Consumption.semanticObjectAction: 'display'
@UI.fieldGroup: [{ position: 20, qualifier: 'DocFlow' }]
invoice_id,   " pulled via _Invoice association
```

---

### Step 6.3 — O2C Pipeline Dashboard (Analytical List Page)

**Backend — Analytical CDS Cube `ZA_O2C_PIPELINE`:**

```abap
@Analytics.dataCategory: #CUBE
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'O2C Pipeline Analytical View'
define view entity ZA_O2C_PIPELINE
  as select from ztab_o2c_hd as hd
  left outer join ztab_o2c_inv_hd as inv  on hd.order_id = inv.order_id
  left outer join ztab_o2c_del_hd as del  on hd.order_id = del.order_id
{
  @Analytics.dimension: true
  key hd.order_id,
  @Analytics.dimension: true
  hd.customer_id,
  @Analytics.dimension: true
  hd.overall_status,
  @Analytics.dimension: true
  hd.order_date,

  @Analytics.measure: true  @Aggregation.default: #SUM
  @Semantics.amount.currencyCode: 'currency_code'
  hd.total_amount,

  @Analytics.measure: true  @Aggregation.default: #SUM
  @Semantics.amount.currencyCode: 'currency_code'
  inv.outstanding_amount,

  @Analytics.measure: true  @Aggregation.default: #SUM
  @Semantics.amount.currencyCode: 'currency_code'
  inv.paid_amount,

  @Analytics.dimension: true
  inv.ar_status,
  @Analytics.dimension: true
  del.delivery_status,
  hd.currency_code
}
```

**Annotate KPIs and Charts on `ZA_O2C_PIPELINE`:**

```abap
" KPI 1: Total Order Value (all statuses)
@UI.KPI: {
  qualifier: 'TotalOrderValueKPI',
  dataPoint: { title: 'Total Order Value', value: 'total_amount', criticality: 'order_criticality' },
  selectionVariantQualifier: 'AllOrders'
}

" KPI 2: Outstanding AR
@UI.KPI: {
  qualifier: 'OutstandingARKPI',
  dataPoint: { title: 'Outstanding AR', value: 'outstanding_amount' },
  selectionVariantQualifier: 'OpenAR'
}

" KPI 3: Total Collected (Paid)
@UI.KPI: {
  qualifier: 'PaidRevenueKPI',
  dataPoint: { title: 'Revenue Collected', value: 'paid_amount' },
  selectionVariantQualifier: 'ClearedAR'
}

" Chart 1: Order Count by Status (Donut)
@UI.chart: [{
  qualifier: 'OrdersByStatus',
  chartType: #DONUT,
  dimensions: ['overall_status'],
  measures: ['total_amount'],
  title: 'Order Value by Status'
}]

" Chart 2: Monthly Order Value (Bar)
@UI.chart: [{
  qualifier: 'MonthlyRevenue',
  chartType: #BAR,
  dimensions: ['order_date'],
  measures: ['total_amount'],
  title: 'Monthly Order Value'
}]
```

**Frontend — New routing target in `manifest.json`:**

```json
{
  "pattern": "Dashboard:?query:",
  "name": "O2CDashboard",
  "target": "O2CDashboard"
}
```

```json
"O2CDashboard": {
  "type": "Component",
  "id": "O2CDashboard",
  "name": "sap.fe.templates.AnalyticalListPage",
  "options": {
    "settings": {
      "contextPath": "/O2CPipeline",
      "defaultVisualizationAnnotationPath": "@com.sap.vocabularies.UI.v1.Chart#OrdersByStatus",
      "variantManagement": "Page",
      "initialLoad": "Enabled"
    }
  }
}
```

Also add a new OData V4 service (`ZUI_O2C_PIPELINE_V4`) bound to the analytical view, separate from the transactional order service.

---

### Step 6.4 — Extend Data Generator for Full O2C Lifecycle

Extend `ZCL_GENERATE_O2C_DATA` to:
1. Delete and re-seed from `ZTAB_O2C_CUSTOMER` and `ZTAB_O2C_MATERIAL` (defer to `ZCL_SEED_O2C_MASTER` or inline it).
2. For orders with status `S`: also insert a corresponding row in `ZTAB_O2C_DEL_HD` with `delivery_status = 'G'`.
3. For delivered orders (50% of them): insert a row in `ZTAB_O2C_INV_HD` with `ar_status = 'O'` and update order status to `'I'`.
4. For invoiced orders (50% of them): insert a row in `ZTAB_O2C_PAY`, update invoice `ar_status = 'C'`, and update order status to `'P'`.
5. Use realistic credit exposure values: `CUST-003` should already be near its limit to demonstrate the credit block feature.

---

## Complete Artifact Checklist

### New Database Tables (9 new)
- [x] `ZTAB_O2C_CUSTOMER` — Customer Master
- [x] `ZTAB_O2C_MATERIAL` — Material Master
- [x] `ZTAB_O2C_DEL_HD` — Delivery Header
- [x] `ZTAB_O2C_DEL_IT` — Delivery Items
- [x] `ZDR_O2C_DEL_HD` — Delivery Header Draft Table
- [x] `ZDR_O2C_DEL_IT` — Delivery Items Draft Table
- [ ] `ZTAB_O2C_INV_HD` — Invoice Header
- [ ] `ZDR_O2C_INV_HD` — Invoice Header Draft Table
- [ ] `ZTAB_O2C_PAY` — Payment Records

### Modified Existing Objects (8 modified)
- [x] `ZTAB_O2C_HD` — Add 4 new fields
- [x] `ZI_O2C_HD` — Join to customer master, add new fields + associations
- [x] `ZC_O2C_HD` — New UI annotations, new facets, new action exposures
- [x] `ZI_O2C_HD.bdef` — New determinations, validations, actions
- [x] `ZBP_I_O2C_HD` — Implement new ABAP methods
- [x] `ZI_O2C_CUSTOMER_VH` — Point to `ZTAB_O2C_CUSTOMER`
- [x] `ZI_O2C_MATERIAL_VH` — Point to `ZTAB_O2C_MATERIAL`
- [ ] `ZI_O2C_STATUS_VH` — Add F, I, P status codes
- [ ] `ZCL_GENERATE_O2C_DATA` — Full O2C lifecycle seeding

### New CDS Views (11 new)
- [x] `ZI_O2C_CUSTOMER` — Customer master interface view
- [x] `ZI_O2C_MATERIAL` — Material master interface view
- [x] `ZI_O2C_DEL_HD` — Delivery header interface view
- [x] `ZI_O2C_DEL_IT` — Delivery items interface view
- [x] `ZC_O2C_DEL_HD` — Delivery header consumption view
- [x] `ZC_O2C_DEL_IT` — Delivery items consumption view
- [ ] `ZI_O2C_INV_HD` — Invoice header interface view
- [ ] `ZC_O2C_INV_HD` — Invoice header consumption view
- [ ] `ZI_O2C_PAY` — Payment interface view
- [ ] `ZC_O2C_PAY` — Payment consumption view
- [ ] `ZA_O2C_PIPELINE` — Analytical cube view for dashboard

### New BDEFs & Behavior Classes (6 new)
- [x] `ZI_O2C_DEL_HD.bdef` — Delivery interface BDEF
- [x] `ZC_O2C_DEL_HD.bdef` — Delivery consumption BDEF
- [x] `ZBP_I_O2C_DEL_HD` — Delivery behavior implementation
- [ ] `ZI_O2C_INV_HD.bdef` — Invoice interface BDEF
- [ ] `ZC_O2C_INV_HD.bdef` — Invoice consumption BDEF
- [ ] `ZBP_I_O2C_INV_HD` — Invoice behavior implementation
- [ ] `ZINV_PAYMENT_INPUT` — Abstract entity for postPayment parameters

### New ABAP Classes (1 new)
- [x] `ZCL_SEED_O2C_MASTER` — Master data seed class

### New Service Objects (3 new)
- [ ] `ZUI_O2C_DEL_V4` — OData V4 Service Definition + Binding for Delivery
- [ ] `ZUI_O2C_INV_V4` — OData V4 Service Definition + Binding for Invoice
- [ ] `ZUI_O2C_PIPELINE_V4` — OData V4 Analytical Service for Dashboard

### Frontend Updates
- [ ] `manifest.json` — Add routing targets for Delivery, Invoice, Dashboard apps
- [ ] Delivery Fiori LR/OP app configuration
- [ ] Invoice Fiori LR/OP app configuration
- [ ] O2C Dashboard (ALP) configuration

---

## Recommended Implementation Sequence

```
Phase 1: Master Data (pre-requisite for everything)
  1.1 → Create ZTAB_O2C_CUSTOMER
  1.2 → Create ZTAB_O2C_MATERIAL
  1.3 → Run ZCL_SEED_O2C_MASTER
  1.4 → Create ZI_O2C_CUSTOMER + update ZI_O2C_CUSTOMER_VH
  1.5 → Create ZI_O2C_MATERIAL + update ZI_O2C_MATERIAL_VH + fix calculateItemTotal

Phase 2: Order Enhancements (build on Phase 1)
  2.1 → Extend ZTAB_O2C_HD (append fields)
  2.2 → Extend ZI_O2C_HD (join + new fields)
  2.3 → Update ZC_O2C_HD annotations + new facet
  2.4 → Update ZI_O2C_HD BDEF + ZC_O2C_HD BDEF
  2.5 → Implement ABAP methods in ZBP_I_O2C_HD
  TEST: Create an order, verify credit check blocks/passes, verify releaseCredit works.

Phase 3: Delivery (build on Phase 2)
  3.1 → [x] Create ZTAB_O2C_DEL_HD + ZTAB_O2C_DEL_IT + draft tables
  3.3 → [x] Create ZI_O2C_DEL_HD + ZI_O2C_DEL_IT + ZC_ views
  3.4 → [x] Create ZI_O2C_DEL_HD BDEF + ZBP_I_O2C_DEL_HD class
  3.5 → [x] Implement createDelivery on ZBP_I_O2C_HD
  3.6 → [x] Implement postGoodsIssue on ZBP_I_O2C_DEL_HD
  3.7 → [x] Add Delivery tab to Order Object Page
  SRV → [x] Create ZUI_O2C_DEL_V4 service
  TEST: Create order → createDelivery → postGoodsIssue → verify stock reduced.

Phase 4: Invoice / AR (build on Phase 3)
  4.1 → Create ZTAB_O2C_INV_HD + draft table
  4.2 → Create ZI_O2C_INV_HD + ZC_O2C_INV_HD CDS stack
  4.3 → Create ZI_O2C_INV_HD BDEF + ZINV_PAYMENT_INPUT abstract entity
  4.4 → Implement createInvoice on ZBP_I_O2C_DEL_HD
  4.5 → Add Invoice tab to Order Object Page
  SRV → Create ZUI_O2C_INV_V4 service
  TEST: postGoodsIssue → createInvoice → verify due date, AR Open, credit_exposure updated.

Phase 5: Payment (build on Phase 4)
  5.1 → Create ZTAB_O2C_PAY
  5.2 → Create ZI_O2C_PAY + ZC_O2C_PAY CDS stack
  5.3 → Implement postPayment on ZBP_I_O2C_INV_HD + ZBP_I_O2C_INV_HD class
  5.4 → Add Payments tab to Invoice Object Page
  TEST: postPayment (partial) → verify AR=Partial Paid. postPayment (full) → verify AR=Cleared,
        order=Paid, credit_exposure reduced.

Phase 6: Dashboard & UI Polish (build on all)
  6.1 → Add document flow navigation/semantic object links
  6.2 → Finalize all 7 status codes in ZI_O2C_HD + STATUS_VH
  6.3 → Create ZA_O2C_PIPELINE analytical view + ALP frontend + ZUI_O2C_PIPELINE_V4
  6.4 → Extend ZCL_GENERATE_O2C_DATA for full lifecycle data
  TEST: Verify dashboard KPIs reflect seeded data across all pipeline stages.
```


---
**Navigation**
⬅️ Previous: [[Phase_5]] | ⬆️ Back to [[Home|Main Plan]]

