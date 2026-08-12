# O2C Full End-to-End Implementation Plan

> **Repository:** `O2C-Sales-Order-App`  
> **Baseline:** Existing Sales Order Management app (Stage 1 complete, Stage 4 status-flag only)  
> **Goal:** Extend the app into a fully demonstrable, chronological Order-to-Cash showcase covering all 7 stages.

---


## Architecture Overview

The complete O2C document chain will be:

```
[Customer Master] <── ZTAB_O2C_CUSTOMER
[Material Master] <── ZTAB_O2C_MATERIAL
        │
        ▼
[Sales Order Header]  ZTAB_O2C_HD  (enhanced)
[Sales Order Items ]  ZTAB_O2C_IT  (enhanced)
        │  (1:1 createDelivery action)
        ▼
[Delivery Header  ]  ZTAB_O2C_DEL_HD  (new)
[Delivery Items   ]  ZTAB_O2C_DEL_IT  (new)
        │  (1:1 createInvoice action)
        ▼
[Invoice Header   ]  ZTAB_O2C_INV_HD  (new)
        │  (postPayment action)
        ▼
[Payment Record   ]  ZTAB_O2C_PAY     (new)
```

Each document entity follows the same RAP stack pattern:
`DB Table → Interface CDS (ZI_) → Consumption CDS (ZC_) → BDEF (ZI_ + ZC_) → Behavior Class (ZBP_)`

---



---

## Phase 1 — Master Data Foundation

**Goal:** Replace free-text customer/material strings and hardcoded ABAP pricing logic with proper master data tables exposed via RAP read-only services.

---

### Step 1.1 — Customer Master Table `ZTAB_O2C_CUSTOMER`
> ✅ **Completed:** Created the transparent table for Customer Master Data.

**Create a new transparent table** in ADT with the following fields:

| Field | Type | Length | Description |
|-------|------|--------|-------------|
| `CLIENT` | `CLNT` | 3 | Mandant (key) |
| `CUSTOMER_ID` | `CHAR` | 10 | Customer ID (key) e.g. `CUST-001` |
| `CUSTOMER_NAME` | `CHAR` | 60 | Full name e.g. "Acme Corp" |
| `CITY` | `CHAR` | 40 | City |
| `COUNTRY` | `CHAR` | 3 | ISO Country Code e.g. `US` |
| `CREDIT_LIMIT` | `CURR` | 15,2 | Credit limit (ref: `CURRENCY`) |
| `CREDIT_EXPOSURE` | `CURR` | 15,2 | Current outstanding exposure (ref: `CURRENCY`) |
| `PAYMENT_TERMS` | `CHAR` | 4 | e.g. `NT30`, `NT60`, `NT90` |
| `CURRENCY` | `CUKY` | 5 | Currency key for credit fields |

**Data Class:** `APPL0`  
**Delivery Class:** `A` (Application data)

---

### Step 1.2 — Material Master Table `ZTAB_O2C_MATERIAL`
> ✅ **Completed:** Created the transparent table for Material Master Data.

**Create a new transparent table** with the following fields:

| Field | Type | Length | Description |
|-------|------|--------|-------------|
| `CLIENT` | `CLNT` | 3 | Mandant (key) |
| `MATERIAL_ID` | `CHAR` | 40 | Material ID (key) e.g. `MAT-100` |
| `MATERIAL_DESC` | `CHAR` | 60 | Description e.g. "Standard Widget" |
| `UNIT_PRICE` | `CURR` | 15,2 | Unit price (ref: `CURRENCY`) |
| `CURRENCY` | `CUKY` | 5 | Currency key |
| `STOCK_QUANTITY` | `QUAN` | 13,3 | Available stock (ref: `UNIT_OF_MEASURE`) |
| `UNIT_OF_MEASURE` | `UNIT` | 3 | e.g. `EA` |
| `MATERIAL_GROUP` | `CHAR` | 10 | e.g. `WIDGETS` |

---

### Step 1.3 — Master Data Seed Class `ZCL_SEED_O2C_MASTER`
> ✅ **Completed:** Created and executed the ABAP class to populate the master tables with initial data.

**Create a new ABAP class** implementing `IF_OO_ADT_CLASSRUN`. Run once in ADT to populate both master tables.

```abap
CLASS zcl_seed_o2c_master DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_seed_o2c_master IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " --- CUSTOMER MASTER ---
    DELETE FROM ztab_o2c_customer.
    INSERT ztab_o2c_customer FROM TABLE @VALUE #(
      ( client = sy-mandt  customer_id = 'CUST-001'  customer_name = 'Acme Corporation'
        city = 'New York'  country = 'US'  credit_limit = '50000'
        credit_exposure = '12000'  payment_terms = 'NT30'  currency = 'USD' )
      ( client = sy-mandt  customer_id = 'CUST-002'  customer_name = 'GlobalTech Ltd'
        city = 'London'    country = 'GB'  credit_limit = '80000'
        credit_exposure = '5000'   payment_terms = 'NT60'  currency = 'USD' )
      ( client = sy-mandt  customer_id = 'CUST-003'  customer_name = 'SkyBridge Inc'
        city = 'Chicago'   country = 'US'  credit_limit = '30000'
        credit_exposure = '29500'  payment_terms = 'NT30'  currency = 'USD' )
      " ... CUST-004 through CUST-010 with varied credit limits
    ).

    " --- MATERIAL MASTER ---
    DELETE FROM ztab_o2c_material.
    INSERT ztab_o2c_material FROM TABLE @VALUE #(
      ( client = sy-mandt  material_id = 'MAT-100'  material_desc = 'Standard Widget'
        unit_price = '150.00'  currency = 'USD'  stock_quantity = '500'
        unit_of_measure = 'EA'  material_group = 'WIDGETS' )
      ( client = sy-mandt  material_id = 'MAT-200'  material_desc = 'Premium Gadget'
        unit_price = '300.00'  currency = 'USD'  stock_quantity = '200'
        unit_of_measure = 'EA'  material_group = 'GADGETS' )
      ( client = sy-mandt  material_id = 'MAT-300'  material_desc = 'Enterprise Module'
        unit_price = '450.00'  currency = 'USD'  stock_quantity = '100'
        unit_of_measure = 'EA'  material_group = 'SOFTWARE' )
    ).

    COMMIT WORK.
    out->write( 'Master data seeded successfully.' ).
  ENDMETHOD.
ENDCLASS.
```

---

### Step 1.4 — Customer Master CDS Stack
> ✅ **Completed:** Built read-only Interface CDS view to expose customer master data.

**1.4a — Interface View `ZI_O2C_CUSTOMER`** (read-only, no RAP behavior needed):

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Customer Master Interface View'
define view entity ZI_O2C_CUSTOMER
  as select from ztab_o2c_customer
{
  key customer_id,
      customer_name,
      city,
      country,
      credit_limit,
      credit_exposure,
      payment_terms,
      currency,
      ( credit_limit - credit_exposure ) as available_credit
}
```

**1.4b — Replace `ZI_O2C_CUSTOMER_VH`** (currently reads from `ZTAB_O2C_HD`):

```abap
@EndUserText.label: 'Customer Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_O2C_CUSTOMER_VH
  as select from ztab_o2c_customer
{
  key customer_id   as CustomerId,
      customer_name as CustomerName,
      city          as City,
      credit_limit  as CreditLimit,
      payment_terms as PaymentTerms
}
```

---

### Step 1.5 — Material Master CDS Stack
> ✅ **Completed:** Built read-only Interface CDS view for material master data. Updated Value Help (F4) in the Item view. Completely automated item entry by fetching `UNIT_PRICE`, `CURRENCY`, and `UNIT_OF_MEASURE` directly from the material master.

**1.5a — Interface View `ZI_O2C_MATERIAL`:**

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Master Interface View'
define view entity ZI_O2C_MATERIAL
  as select from ztab_o2c_material
{
  key material_id,
      material_desc,
      unit_price,
      currency,
      stock_quantity,
      unit_of_measure,
      material_group
}
```

**1.5b — Replace `ZI_O2C_MATERIAL_VH`** (currently reads from `ZTAB_O2C_IT` with hardcoded CASE):

```abap
@EndUserText.label: 'Material Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_O2C_MATERIAL_VH
  as select from ztab_o2c_material
{
  key material_id   as MaterialId,
      material_desc as MaterialDescription,
      unit_price    as Price,
      currency      as Currency,
      stock_quantity as StockQuantity
}
```

**1.5c — Update `calculateItemTotal` in `ZBP_I_O2C_HD`** to read from `ZTAB_O2C_MATERIAL` instead of the hardcoded CASE:

```abap
" Replace the CASE block with a SELECT from the material master:
SELECT SINGLE unit_price, currency
  FROM ztab_o2c_material
  WHERE material_id = @item-material_id
  INTO @DATA(ls_mat).

item_amount   = item-quantity * ls_mat-unit_price.
currency_code = ls_mat-currency.
```

---



---

## Phase 2 — Order Header Enhancements (Stages 1 & 2)

**Goal:** Add temporal fields and credit-check logic to the Sales Order.

---

### Step 2.1 — Extend `ZTAB_O2C_HD` with New Fields
> ✅ **Completed:** Added new temporal fields (`order_date`, `requested_delivery_date`), payment/financial fields (`payment_terms`, `credit_check_status`), and dummy fields to `ZTAB_O2C_HD` and the Draft table `ZDR_O2C_HD`.

Add the following fields to the existing header table (additive only — append to field list):

| New Field | Type | Description |
|-----------|------|-------------|
| `ORDER_DATE` | `DATS` | Date the order was placed |
| `REQUESTED_DELIVERY_DATE` | `DATS` | Customer's requested delivery date |
| `PAYMENT_TERMS` | `CHAR(4)` | Copied from Customer Master on creation |
| `CREDIT_CHECK_STATUS` | `CHAR(1)` | `P`=Passed, `F`=Failed/Blocked, `R`=Released |

---

### Step 2.2 — Extend `ZI_O2C_HD` (Interface CDS View)
> ✅ **Completed:** Joined `ZTAB_O2C_CUST` to display `customer_name`. Implemented `CASE` logic for human-readable status texts and UI criticality colors.

Add the four new fields and a left outer join to the Customer Master for display:

```abap
define root view entity ZI_O2C_HD
  as select from ztab_o2c_hd as hd
  left outer join ztab_o2c_customer as cust
    on hd.customer_id = cust.customer_id
  composition [0..*] of ZI_O2C_IT as _Items
{
  key hd.order_id,
      hd.customer_id,
      cust.customer_name,                -- NEW: pulled from customer master
      hd.order_date,                     -- NEW
      hd.requested_delivery_date,        -- NEW
      hd.payment_terms,                  -- NEW
      hd.overall_status,
      cast( case hd.overall_status
        when 'D' then 'Draft'
        when 'O' then 'Open'
        when 'F' then 'In Fulfilment'
        when 'S' then 'Shipped'
        when 'I' then 'Invoiced'
        when 'P' then 'Paid / Closed'
        when 'C' then 'Cancelled'
        else 'Unknown'
      end as abap.char( 20 )) as overall_status_text,
      hd.credit_check_status,            -- NEW
      cast( case hd.credit_check_status
        when 'P' then 'Credit OK'
        when 'F' then 'Credit Blocked'
        when 'R' then 'Manually Released'
        else 'Not Checked'
      end as abap.char( 25 )) as credit_check_status_text,
      case hd.credit_check_status
        when 'P' then 3  " green
        when 'R' then 2  " yellow
        when 'F' then 1  " red
        else 0
      end as credit_check_criticality,
      @Semantics.amount.currencyCode: 'currency_code'
      hd.total_amount,
      hd.currency_code,
      hd.created_by,
      hd.last_changed_at,
      _Items
}
```

---

### Step 2.3 — Update `ZC_O2C_HD` (Consumption CDS) Annotations
> ✅ **Completed:** Added new fields to UI Facets (General Information group) and exposed the `Release Credit Block` action button in the Fiori UI.

Add UI annotations for the new fields:

```abap
" In FieldGroup 'GQ1' (Order Info):
@EndUserText.label: 'Order Date'
@UI.fieldGroup: [{ position: 5, qualifier: 'GQ1' }]
@UI.lineItem: [{ position: 5 }]
order_date,

@EndUserText.label: 'Customer Name'
@UI.lineItem: [{ position: 15 }]
@UI.fieldGroup: [{ position: 15, qualifier: 'GQ1' }]
customer_name,

@EndUserText.label: 'Requested Delivery Date'
@UI.fieldGroup: [{ position: 40, qualifier: 'GQ1' }]
requested_delivery_date,

@EndUserText.label: 'Payment Terms'
@UI.fieldGroup: [{ position: 50, qualifier: 'GQ1' }]
payment_terms,

" New FieldGroup 'GQ_CREDIT' (Credit & Payment Info):
@EndUserText.label: 'Credit Check Status'
@UI.lineItem: [{ position: 35, criticality: 'credit_check_criticality' }]
@UI.fieldGroup: [{ position: 10, qualifier: 'GQ_CREDIT' }]
@UI.identification: [
  { type: #FOR_ACTION, dataAction: 'releaseCredit',
    label: 'Release Credit Block', requiresContext: true }
]
@UI.dataPoint: { qualifier: 'CreditCheckDP', title: 'Credit Status' }
credit_check_status,

@UI.hidden: true
credit_check_status_text,
@UI.hidden: true
credit_check_criticality,
```

Add the Credit Check facet to `@UI.facet`:

```abap
{
  id: 'CreditInfo',
  type: #FIELDGROUP_REFERENCE,
  parentId: 'HeaderData',
  label: 'Credit & Payment',
  position: 30,
  targetQualifier: 'GQ_CREDIT'
},
```

---

### Step 2.4 — Update `ZI_O2C_HD` BDEF — New Actions & Determinations
> ✅ **Completed:** Exposed new fields and actions (`releaseCredit`, `createDelivery`). Added Determinations for payment terms and credit limits. Configured `side effects` to instantly refresh `payment_terms`, `customer_name`, and `order_date`.

```abap
" Add to the OrderHeader behavior block:
field ( readonly ) credit_check_status, credit_check_status_text,
                   credit_check_criticality, customer_name;
field ( mandatory ) order_date;

" New determination: copy payment terms from Customer Master on creation
determination setPaymentTerms on modify { create; field customer_id; }

" New validation: credit check evaluated at save time
validation checkCreditLimit on save { field customer_id, total_amount; create; update; }

" New action: manually release a credit block
action ( features : instance ) releaseCredit result [1] $self;

" New action: triggers Delivery creation (Phase 3)
action ( features : instance ) createDelivery result [1] $self;
```

Also update `get_instance_features` to disable `shipOrder` when credit is blocked:

```abap
%action-shipOrder = COND #(
  WHEN ls_order-overall_status = 'S' OR ls_order-overall_status = 'C'
    THEN if_abap_behv=>fc-o-disabled
  WHEN ls_order-credit_check_status = 'F'   " <-- NEW
    THEN if_abap_behv=>fc-o-disabled
  ELSE if_abap_behv=>fc-o-enabled )

" Also disable createDelivery if not Open or if credit blocked:
%action-createDelivery = COND #(
  WHEN ls_order-overall_status <> 'O' OR ls_order-credit_check_status = 'F'
    THEN if_abap_behv=>fc-o-disabled
  ELSE if_abap_behv=>fc-o-enabled )
```

---

### Step 2.5 — Implement New Logic in `ZBP_I_O2C_HD`
> ✅ **Completed:** Implemented `setPaymentTerms` (auto-populates order date and payment terms), `checkCreditLimit` (blocks order and sets warning message), `releaseCredit` (manually overrides block), and dynamic instance feature control.

**2.5a — `setPaymentTerms` determination** (sets order_date, copies payment terms from customer):

```abap
METHOD setPaymentTerms.
  READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
    ENTITY OrderHeader FIELDS ( customer_id ) WITH CORRESPONDING #( keys )
    RESULT DATA(lt_orders).

  LOOP AT lt_orders INTO DATA(ls_order).
    SELECT SINGLE payment_terms FROM ztab_o2c_customer
      WHERE customer_id = @ls_order-customer_id
      INTO @DATA(lv_terms).

    MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( payment_terms order_date )
        WITH VALUE #( ( %tky          = ls_order-%tky
                        payment_terms = lv_terms
                        order_date    = cl_abap_context_info=>get_system_date( ) ) ).
  ENDLOOP.
ENDMETHOD.
```

**2.5b — `checkCreditLimit` validation:**

```abap
METHOD checkCreditLimit.
  READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
    ENTITY OrderHeader FIELDS ( customer_id total_amount ) WITH CORRESPONDING #( keys )
    RESULT DATA(lt_orders).

  LOOP AT lt_orders INTO DATA(ls_order).
    SELECT SINGLE credit_limit, credit_exposure FROM ztab_o2c_customer
      WHERE customer_id = @ls_order-customer_id
      INTO @DATA(ls_cust).

    DATA(lv_available) = ls_cust-credit_limit - ls_cust-credit_exposure.

    IF ls_order-total_amount > lv_available.
      MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
        ENTITY OrderHeader UPDATE FIELDS ( credit_check_status )
        WITH VALUE #( ( %tky = ls_order-%tky  credit_check_status = 'F' ) ).

      APPEND VALUE #(
          %tky = ls_order-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-warning
            text = |Warning: Order { ls_order-order_id } exceeds credit limit. Shipment blocked.|
          )
      ) TO reported-orderheader.
    ELSE.
      MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
        ENTITY OrderHeader UPDATE FIELDS ( credit_check_status )
        WITH VALUE #( ( %tky = ls_order-%tky  credit_check_status = 'P' ) ).
    ENDIF.
  ENDLOOP.
ENDMETHOD.
```

**2.5c — `releaseCredit` action:**

```abap
METHOD releaseCredit.
  MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
    ENTITY OrderHeader UPDATE FIELDS ( credit_check_status )
    WITH VALUE #( FOR key IN keys ( %tky = key-%tky  credit_check_status = 'R' ) )
    FAILED failed  REPORTED reported.

  READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
    ENTITY OrderHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_orders).

  result = VALUE #( FOR ls IN lt_orders ( %tky = ls-%tky  %param = ls ) ).

  LOOP AT lt_orders INTO DATA(ls_msg).
    APPEND VALUE #(
        %tky = ls_msg-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text = |Credit block manually released for Order { ls_msg-order_id }.|
        )
    ) TO reported-orderheader.
  ENDLOOP.
ENDMETHOD.
```

---



---

## Phase 3 — Fulfilment & Delivery (Stages 3 & 4)

**Goal:** Replace the `Ship Order` status-flip with a proper Delivery document with goods-issue and stock reduction.

---

### Step 3.1 — Delivery Header Table `ZTAB_O2C_DEL_HD`

| Field | Type | Description |
|-------|------|-------------|
| `CLIENT` | `CLNT` | Mandant (key) |
| `DELIVERY_ID` | `CHAR(10)` | Delivery number (key) e.g. `DEL-0001` |
| `ORDER_ID` | `CHAR(10)` | FK to Sales Order |
| `CUSTOMER_ID` | `CHAR(10)` | Denormalized for display |
| `DELIVERY_DATE` | `DATS` | Actual dispatch date |
| `CARRIER` | `CHAR(30)` | Carrier name e.g. "FedEx" |
| `TRACKING_NUMBER` | `CHAR(30)` | Shipment tracking reference |
| `DELIVERY_STATUS` | `CHAR(1)` | `P`=Pending, `G`=Goods Issued, `D`=Delivered |
| `GOODS_ISSUE_DATE` | `DATS` | Date goods were issued |
| `CURRENCY_CODE` | `CUKY(5)` | Currency |
| `CREATED_BY` | `CHAR(12)` | Creator user ID |
| `LAST_CHANGED_AT` | `TIMESTAMPL` | Optimistic lock etag |

Also create a draft table `ZDR_O2C_DEL_HD` with the same structure plus standard RAP draft fields.

---

### Step 3.2 — Delivery Items Table `ZTAB_O2C_DEL_IT`

| Field | Type | Description |
|-------|------|-------------|
| `CLIENT` | `CLNT` | Mandant (key) |
| `DELIVERY_ID` | `CHAR(10)` | FK to Delivery Header (key) |
| `DELIVERY_ITEM` | `NUMC(4)` | Item position (key) |
| `ORDER_ITEM_POSITION` | `NUMC(4)` | FK to Sales Order item |
| `MATERIAL_ID` | `CHAR(40)` | Material |
| `QUANTITY_ORDERED` | `QUAN(13,3)` | Ordered quantity |
| `QUANTITY_DELIVERED` | `QUAN(13,3)` | Actual delivered qty |
| `UNIT_OF_MEASURE` | `UNIT(3)` | UoM |

Also create `ZDR_O2C_DEL_IT` draft table.

---

### Step 3.3 — Delivery CDS Stack

**Interface View `ZI_O2C_DEL_HD`:**

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery Header Interface View'
define root view entity ZI_O2C_DEL_HD
  as select from ztab_o2c_del_hd as del
  association to parent ZI_O2C_HD as _Order
    on $projection.order_id = _Order.order_id
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
        when 'G' then 3  " green
        when 'D' then 3  " green
        when 'P' then 2  " yellow
        else 0
      end as delivery_status_criticality,
      del.goods_issue_date,
      del.created_by,
      del.last_changed_at,
      _Order,
      _DeliveryItems
}
```

**Interface View `ZI_O2C_DEL_IT`:**

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery Items Interface View'
define view entity ZI_O2C_DEL_IT
  as select from ztab_o2c_del_it
  association to parent ZI_O2C_DEL_HD as _DeliveryHeader
    on $projection.delivery_id = _DeliveryHeader.delivery_id
{
  key delivery_id,
  key delivery_item,
      order_item_position,
      material_id,
      quantity_ordered,
      quantity_delivered,
      unit_of_measure,
      _DeliveryHeader
}
```

**Consumption Views `ZC_O2C_DEL_HD` and `ZC_O2C_DEL_IT`:** Mirror the Sales Order pattern. Add `@UI.facet` for General Info (delivery_id, order_id, customer_id, delivery_date, carrier, tracking_number, goods_issue_date) and a Delivery Items tab. Add `@UI.lineItem` annotations for the list report columns. Add `@UI.dataPoint` for `delivery_status` as a KPI header badge.

---

### Step 3.4 — Delivery BDEF `ZI_O2C_DEL_HD`

```abap
managed implementation in class zbp_i_o2c_del_hd unique;
strict ( 2 );
with draft;

define behavior for ZI_O2C_DEL_HD alias DeliveryHeader
early numbering
persistent table ztab_o2c_del_hd
draft table zdr_o2c_del_hd
lock master total etag last_changed_at
authorization master ( global )
{
  create; update; delete;
  association _DeliveryItems { create; with draft; }

  field ( readonly ) delivery_id, delivery_status, goods_issue_date, created_by;
  field ( mandatory ) order_id, delivery_date;

  action ( features : instance ) postGoodsIssue  result [1] $self;
  action ( features : instance ) createInvoice   result [1] $self;

  determination setInitialDeliveryStatus  on modify { create; }
  determination copyOrderItemsToDelivery  on modify { create; field order_id; }

  draft action Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare { }

  mapping for ztab_o2c_del_hd { ... }
}

define behavior for ZI_O2C_DEL_IT alias DeliveryItem
early numbering
persistent table ztab_o2c_del_it
draft table zdr_o2c_del_it
lock dependent by _DeliveryHeader
authorization dependent by _DeliveryHeader
{
  update; delete;
  field ( readonly ) delivery_id;
  mapping for ztab_o2c_del_it { ... }
}
```

`get_instance_features` on Delivery should disable `postGoodsIssue` if status is already `G` or `D`, and disable `createInvoice` if status is not yet `G`.

---

### Step 3.5 — `createDelivery` Action Implementation (in `ZBP_I_O2C_HD`)

```abap
METHOD createDelivery.
  READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
    ENTITY OrderHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_orders).

  LOOP AT lt_orders INTO DATA(ls_order).
    IF ls_order-overall_status <> 'O' OR ls_order-credit_check_status = 'F'.
      CONTINUE.
    ENDIF.

    " Compute next delivery ID
    SELECT MAX( delivery_id ) FROM ztab_o2c_del_hd INTO @DATA(lv_max_del).
    " ... apply same numbering pattern as orders (extract numeric suffix + 1)

    " Create the Delivery Header via inter-entity EML
    MODIFY ENTITIES OF zi_o2c_del_hd
      ENTITY DeliveryHeader
        CREATE FIELDS ( order_id customer_id delivery_date delivery_status )
        WITH VALUE #( ( %cid            = |cid_{ ls_order-order_id }|
                        order_id        = ls_order-order_id
                        customer_id     = ls_order-customer_id
                        delivery_date   = cl_abap_context_info=>get_system_date( )
                        delivery_status = 'P' ) )
      MAPPED DATA(mapped_del)  FAILED DATA(failed_del)  REPORTED DATA(reported_del).

    " Advance Sales Order status to 'F' (In Fulfilment)
    MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader UPDATE FIELDS ( overall_status )
      WITH VALUE #( ( %tky = ls_order-%tky  overall_status = 'F' ) ).

    COMMIT ENTITIES.

    APPEND VALUE #(
        %tky = ls_order-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text = |Delivery created for Order { ls_order-order_id }. Status: In Fulfilment.|
        )
    ) TO reported-orderheader.
  ENDLOOP.

  READ ENTITIES OF zi_o2c_hd IN LOCAL MODE
    ENTITY OrderHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_updated).
  result = VALUE #( FOR ls IN lt_updated ( %tky = ls-%tky  %param = ls ) ).
ENDMETHOD.
```

---

### Step 3.6 — `postGoodsIssue` Action Implementation (in `ZBP_I_O2C_DEL_HD`)

```abap
METHOD postGoodsIssue.
  READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
    ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_deliveries).

  LOOP AT lt_deliveries INTO DATA(ls_del).
    " 1. Read delivery items and reduce stock in material master
    READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
      ENTITY DeliveryHeader BY _DeliveryItems
        FIELDS ( material_id quantity_delivered )
        WITH VALUE #( ( %tky = ls_del-%tky ) )
      RESULT DATA(lt_items).

    LOOP AT lt_items INTO DATA(ls_item).
      UPDATE ztab_o2c_material
        SET stock_quantity = stock_quantity - @ls_item-quantity_delivered
        WHERE material_id = @ls_item-material_id.
    ENDLOOP.

    " 2. Set Delivery status to 'G' (Goods Issued)
    MODIFY ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
      ENTITY DeliveryHeader UPDATE FIELDS ( delivery_status goods_issue_date )
      WITH VALUE #( ( %tky             = ls_del-%tky
                      delivery_status  = 'G'
                      goods_issue_date = cl_abap_context_info=>get_system_date( ) ) ).

    " 3. Update parent Sales Order status to 'S' (Shipped)
    MODIFY ENTITIES OF zi_o2c_hd IN LOCAL MODE
      ENTITY OrderHeader UPDATE FIELDS ( overall_status )
      WITH VALUE #( ( %tky-order_id  = ls_del-order_id
                      %tky-%is_draft = if_abap_behv=>mk-off
                      overall_status = 'S' ) ).

    APPEND VALUE #(
        %tky = ls_del-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text = |Goods Issue posted for { ls_del-delivery_id }. Stock updated. Order marked Shipped.|
        )
    ) TO reported-deliveryheader.
  ENDLOOP.

  READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
    ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_updated).
  result = VALUE #( FOR ls IN lt_updated ( %tky = ls-%tky  %param = ls ) ).
ENDMETHOD.
```

---

### Step 3.7 — Expose Delivery as a Tab on the Order Object Page

In `ZI_O2C_HD` CDS, add the association:

```abap
association [0..1] to ZI_O2C_DEL_HD as _Delivery
  on $projection.order_id = _Delivery.order_id
```

In `ZC_O2C_HD`, add the facet:

```abap
{
  id: 'Delivery',
  type: #LINEITEM_REFERENCE,
  label: 'Delivery',
  position: 30,
  targetElement: '_Delivery'
},
```

Also add `createDelivery` action to the `ZC_O2C_HD` BDEF using `use action createDelivery;`.

---



---

## Phase 4 — Billing & Accounts Receivable (Stages 5 & 6)

**Goal:** Create an Invoice document triggered from the Delivery with AR tracking.

---

### Step 4.1 — Invoice Header Table `ZTAB_O2C_INV_HD`

| Field | Type | Description |
|-------|------|-------------|
| `CLIENT` | `CLNT` | Mandant (key) |
| `INVOICE_ID` | `CHAR(10)` | Invoice number (key) e.g. `INV-0001` |
| `ORDER_ID` | `CHAR(10)` | FK to Sales Order |
| `DELIVERY_ID` | `CHAR(10)` | FK to Delivery |
| `CUSTOMER_ID` | `CHAR(10)` | Customer reference |
| `INVOICE_DATE` | `DATS` | Date invoice was raised |
| `DUE_DATE` | `DATS` | Payment due date |
| `GROSS_AMOUNT` | `CURR(15,2)` | Total invoice value |
| `PAID_AMOUNT` | `CURR(15,2)` | Cumulative amount paid |
| `OUTSTANDING_AMOUNT` | `CURR(15,2)` | Gross minus Paid |
| `CURRENCY_CODE` | `CUKY(5)` | Currency |
| `AR_STATUS` | `CHAR(1)` | `O`=Open, `P`=Partially Paid, `C`=Cleared |
| `PAYMENT_TERMS` | `CHAR(4)` | NT30 / NT60 / NT90 |
| `CREATED_BY` | `CHAR(12)` | Creator |
| `LAST_CHANGED_AT` | `TIMESTAMPL` | Etag |

Also create `ZDR_O2C_INV_HD` draft table.

---

### Step 4.2 — Invoice CDS Stack

**Interface View `ZI_O2C_INV_HD`:**

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Invoice Header Interface View'
define root view entity ZI_O2C_INV_HD
  as select from ztab_o2c_inv_hd as inv
  association to ZI_O2C_HD     as _Order    on $projection.order_id    = _Order.order_id
  association to ZI_O2C_DEL_HD as _Delivery on $projection.delivery_id = _Delivery.delivery_id
{
  key inv.invoice_id,
      inv.order_id,
      inv.delivery_id,
      inv.customer_id,
      inv.invoice_date,
      inv.due_date,
      @Semantics.amount.currencyCode: 'currency_code'
      inv.gross_amount,
      @Semantics.amount.currencyCode: 'currency_code'
      inv.paid_amount,
      @Semantics.amount.currencyCode: 'currency_code'
      inv.outstanding_amount,
      inv.currency_code,
      inv.ar_status,
      cast( case inv.ar_status
        when 'O' then 'Open'
        when 'P' then 'Partially Paid'
        when 'C' then 'Cleared'
        else 'Unknown'
      end as abap.char( 20 )) as ar_status_text,
      case inv.ar_status
        when 'C' then 3  " green
        when 'P' then 2  " yellow
        when 'O' then 1  " red
        else 0
      end as ar_status_criticality,
      inv.payment_terms,
      inv.created_by,
      inv.last_changed_at,
      _Order,
      _Delivery
}
```

**Consumption View `ZC_O2C_INV_HD`:** Projection view with `@UI.facet` for Invoice Info and Financial Details. Include `@UI.dataPoint` for `outstanding_amount` as a KPI header badge with criticality based on `ar_status_criticality`. Add `postPayment` to `@UI.identification`.

---

### Step 4.3 — Invoice BDEF `ZI_O2C_INV_HD`

```abap
managed implementation in class zbp_i_o2c_inv_hd unique;
strict ( 2 );
with draft;

define behavior for ZI_O2C_INV_HD alias InvoiceHeader
early numbering
persistent table ztab_o2c_inv_hd
draft table zdr_o2c_inv_hd
lock master total etag last_changed_at
authorization master ( global )
{
  " No standalone create — invoices are created only via createInvoice action on Delivery
  update; delete;

  field ( readonly ) invoice_id, order_id, delivery_id, customer_id,
                     gross_amount, outstanding_amount, ar_status,
                     ar_status_text, ar_status_criticality,
                     paid_amount, invoice_date, due_date, created_by;

  action ( features : instance ) postPayment
    parameter zinv_payment_input
    result [1] $self;

  draft action Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;

  mapping for ztab_o2c_inv_hd { ... }
}
```

Also define the abstract input entity for `postPayment` parameters:

```abap
define abstract entity zinv_payment_input
{
  payment_amount  : ztab_o2c_inv_hd-gross_amount;
  payment_method  : ztab_o2c_pay-payment_method;
  reference       : ztab_o2c_pay-reference;
}
```

---

### Step 4.4 — `createInvoice` Action Implementation (in `ZBP_I_O2C_DEL_HD`)

Only available when `delivery_status = 'G'` (Goods Issued):

```abap
METHOD createInvoice.
  READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
    ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_deliveries).

  LOOP AT lt_deliveries INTO DATA(ls_del).
    IF ls_del-delivery_status <> 'G'.  CONTINUE.  ENDIF.

    " Get total amount and payment terms from the parent Sales Order
    READ ENTITIES OF zi_o2c_hd
      ENTITY OrderHeader FIELDS ( total_amount currency_code payment_terms customer_id )
      WITH VALUE #( ( %tky-order_id  = ls_del-order_id
                      %tky-%is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_orders).
    READ TABLE lt_orders INTO DATA(ls_order) INDEX 1.

    " Compute due date from payment terms
    DATA(lv_days) = COND i( WHEN ls_order-payment_terms = 'NT30' THEN 30
                             WHEN ls_order-payment_terms = 'NT60' THEN 60
                             WHEN ls_order-payment_terms = 'NT90' THEN 90
                             ELSE 30 ).
    DATA(lv_due_date)     = cl_abap_context_info=>get_system_date( ) + lv_days.
    DATA(lv_invoice_date) = cl_abap_context_info=>get_system_date( ).

    " 1. Create Invoice via EML (Early Numbering generates ID)
    MODIFY ENTITIES OF zi_o2c_inv_hd
      ENTITY InvoiceHeader
        CREATE FIELDS ( order_id delivery_id customer_id invoice_date due_date
                        gross_amount outstanding_amount paid_amount
                        currency_code payment_terms ar_status )
        WITH VALUE #( ( %cid               = |cid_inv_{ ls_del-delivery_id }|
                        order_id           = ls_del-order_id
                        delivery_id        = ls_del-delivery_id
                        customer_id        = ls_del-customer_id
                        invoice_date       = lv_invoice_date
                        due_date           = lv_due_date
                        gross_amount       = ls_order-total_amount
                        outstanding_amount = ls_order-total_amount
                        paid_amount        = 0
                        currency_code      = ls_order-currency_code
                        payment_terms      = ls_order-payment_terms
                        ar_status          = 'O' ) )
      MAPPED DATA(mapped_inv)  FAILED DATA(failed_inv)  REPORTED DATA(rep_inv).

    " 2. Update Delivery status to 'D' (Invoiced)
    MODIFY ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
      ENTITY DeliveryHeader UPDATE FIELDS ( delivery_status )
      WITH VALUE #( ( %tky = ls_del-%tky  delivery_status = 'D' ) ).

    " 3. Queue Sales Order status update for the Save Phase
    APPEND VALUE #( order_id = ls_del-order_id
                    status   = 'I' ) TO zbp_i_o2c_del_hd=>gt_status_updates.

    " 4. Queue Customer Credit Exposure update
    APPEND VALUE #( customer_id = ls_del-customer_id
                    amount      = ls_order-total_amount ) TO zbp_i_o2c_del_hd=>gt_credit_updates.

    " 5. Success Message
    APPEND VALUE #(
        %tky = ls_del-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text = |Invoice created! Due Date: { lv_due_date }. AR is Open.|
        )
    ) TO reported-deliveryheader.
  ENDLOOP.

  " Return updated delivery back to UI
  READ ENTITIES OF zi_o2c_del_hd IN LOCAL MODE
    ENTITY DeliveryHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_updated).
  result = VALUE #( FOR ls IN lt_updated ( %tky = ls-%tky  %param = ls ) ).
ENDMETHOD.
```

**Saver Class Implementation:**
The direct DB updates must be executed in `save_modified` to comply with RAP Strict Mode.

```abap
CLASS lsc_ZI_O2C_DEL_HD IMPLEMENTATION.
  METHOD save_modified.
    " Execute Customer Credit Exposure Updates
    LOOP AT zbp_i_o2c_del_hd=>gt_credit_updates INTO DATA(ls_credit).
      UPDATE ztab_o2c_cust
        SET credit_exposure = credit_exposure + @ls_credit-amount
        WHERE customer_id = @ls_credit-customer_id.
    ENDLOOP.

    " Execute Sales Order Status Updates
    LOOP AT zbp_i_o2c_del_hd=>gt_status_updates INTO DATA(ls_status).
      UPDATE ztab_o2c_hd
        SET overall_status = @ls_status-status
        WHERE order_id = @ls_status-order_id.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

---

### Step 4.5 — Expose Invoice as a Tab on the Order Object Page

In `ZI_O2C_HD` CDS:

```abap
association [0..1] to ZI_O2C_INV_HD as _Invoice
  on $projection.order_id = _Invoice.order_id
```

In `ZC_O2C_HD`, add facet:

```abap
{
  id: 'Invoice',
  type: #LINEITEM_REFERENCE,
  label: 'Invoice / AR',
  position: 40,
  targetElement: '_Invoice'
},
```

---



---

## Phase 5 — Payment & Reconciliation (Stage 7)

**Goal:** Record customer payments against invoices and close AR items.

---

### Step 5.1 — Payment Table `ZTAB_O2C_PAY`

| Field | Type | Description |
|-------|------|-------------|
| `CLIENT` | `CLNT` | Mandant (key) |
| `PAYMENT_ID` | `CHAR(10)` | Payment reference (key) e.g. `PAY-0001` |
| `INVOICE_ID` | `CHAR(10)` | FK to Invoice |
| `ORDER_ID` | `CHAR(10)` | Denormalized FK |
| `CUSTOMER_ID` | `CHAR(10)` | Denormalized FK |
| `PAYMENT_DATE` | `DATS` | Date payment was received |
| `PAYMENT_AMOUNT` | `CURR(15,2)` | Amount paid |
| `CURRENCY_CODE` | `CUKY(5)` | Currency |
| `PAYMENT_METHOD` | `CHAR(10)` | `BANK`, `CREDIT`, `WIRE` |
| `REFERENCE` | `CHAR(30)` | Bank reference or cheque number |
| `CREATED_BY` | `CHAR(12)` | User who posted the payment |
| `CREATED_AT` | `TIMESTAMPL` | Posting timestamp |

---

### Step 5.2 — Payment CDS Stack

**Interface View `ZI_O2C_PAY`:**

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment Interface View'
define root view entity ZI_O2C_PAY
  as select from ztab_o2c_pay as pay
  association to ZI_O2C_INV_HD as _Invoice
    on $projection.invoice_id = _Invoice.invoice_id
{
  key pay.payment_id,
      pay.invoice_id,
      pay.order_id,
      pay.customer_id,
      pay.payment_date,
      @Semantics.amount.currencyCode: 'currency_code'
      pay.payment_amount,
      pay.currency_code,
      pay.payment_method,
      pay.reference,
      pay.created_by,
      pay.created_at,
      _Invoice
}
```

**Consumption View `ZC_O2C_PAY`:** Read-only projection with list report annotations showing payment_id, invoice_id, payment_date, payment_amount, payment_method, reference columns.

---

### Step 5.3 — `postPayment` Action Implementation (in `ZBP_I_O2C_INV_HD`)

```abap
METHOD postPayment.
  READ ENTITIES OF zi_o2c_inv_hd IN LOCAL MODE
    ENTITY InvoiceHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_invoices).

  LOOP AT lt_invoices INTO DATA(ls_inv).
    IF ls_inv-ar_status = 'C'.  CONTINUE.  ENDIF.

    " Get the popup parameters entered by the user
    READ TABLE keys INTO DATA(ls_key) WITH KEY id COMPONENTS %tky = ls_inv-%tky.
    DATA lv_new_paid        TYPE ztab_o2c_inv_hd-paid_amount.
    DATA lv_new_outstanding TYPE ztab_o2c_inv_hd-outstanding_amount.

    DATA(lv_pay_amount) = ls_key-%param-payment_amount.
    lv_new_paid         = ls_inv-paid_amount + lv_pay_amount.
    lv_new_outstanding  = ls_inv-gross_amount - lv_new_paid.
    DATA(lv_new_ar_status) = COND #( WHEN lv_new_outstanding <= 0 THEN 'C' ELSE 'P' ).

    " 1. Update Invoice AR fields
    MODIFY ENTITIES OF zi_o2c_inv_hd IN LOCAL MODE
      ENTITY InvoiceHeader UPDATE FIELDS ( paid_amount outstanding_amount ar_status )
      WITH VALUE #( ( %tky               = ls_inv-%tky
                      paid_amount        = lv_new_paid
                      outstanding_amount = lv_new_outstanding
                      ar_status          = lv_new_ar_status ) )
      FAILED failed  REPORTED reported.

    " 2. Queue Payment Record for DB Insertion in the Save Phase
    SELECT MAX( payment_id ) FROM ztab_o2c_pay INTO @DATA(lv_max_pay).
    DATA: lv_next_pay TYPE n LENGTH 6.
    IF lv_max_pay IS INITIAL.
      lv_next_pay = 1.
    ELSE.
      lv_next_pay = lv_max_pay+4(6) + 1.
    ENDIF.
    
    APPEND VALUE #( 
        payment_id     = |PAY-{ lv_next_pay }|
        invoice_id     = ls_inv-invoice_id
        order_id       = ls_inv-order_id
        customer_id    = ls_inv-customer_id
        payment_date   = cl_abap_context_info=>get_system_date( )
        payment_amount = lv_pay_amount
        currency_code  = ls_inv-currency_code
        payment_method = ls_key-%param-payment_method
        reference      = ls_key-%param-reference
    ) TO zbp_i_o2c_inv_hd=>gt_payments.

    " 3. If Fully Cleared, queue Credit Exposure & Order Status updates
    IF lv_new_ar_status = 'C'.
      APPEND VALUE #( customer_id = ls_inv-customer_id
                      amount      = ls_inv-gross_amount ) TO zbp_i_o2c_inv_hd=>gt_credit_updates.
                      
      APPEND VALUE #( order_id = ls_inv-order_id
                      status   = 'P' ) TO zbp_i_o2c_inv_hd=>gt_status_updates.
    ENDIF.

    " 4. Success Message
    APPEND VALUE #(
        %tky = ls_inv-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text = COND #( WHEN lv_new_ar_status = 'C'
                          THEN |Invoice { ls_inv-invoice_id } fully cleared!|
                          ELSE |Payment of { lv_pay_amount } posted. Outstanding: { lv_new_outstanding }| )
        )
    ) TO reported-invoiceheader.
  ENDLOOP.

  READ ENTITIES OF zi_o2c_inv_hd IN LOCAL MODE
    ENTITY InvoiceHeader ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_updated).
  result = VALUE #( FOR ls IN lt_updated ( %tky = ls-%tky  %param = ls ) ).
ENDMETHOD.
```

**Saver Class Implementation:**
The direct DB updates must be executed in `save_modified` to comply with RAP Strict Mode.

```abap
CLASS lsc_ZI_O2C_INV_HD IMPLEMENTATION.
  METHOD save_modified.
    DATA lv_timestamp TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_timestamp.

    " Insert new Payment lines
    LOOP AT zbp_i_o2c_inv_hd=>gt_payments INTO DATA(ls_pay).
      INSERT ztab_o2c_pay FROM @( VALUE #(
        client         = sy-mandt
        payment_id     = ls_pay-payment_id
        invoice_id     = ls_pay-invoice_id
        order_id       = ls_pay-order_id
        customer_id    = ls_pay-customer_id
        payment_date   = ls_pay-payment_date
        payment_amount = ls_pay-payment_amount
        currency_code  = ls_pay-currency_code
        payment_method = ls_pay-payment_method
        reference      = ls_pay-reference
        created_by     = sy-uname
        created_at     = lv_timestamp
      ) ).
    ENDLOOP.

    " Reduce Customer Credit Exposure
    LOOP AT zbp_i_o2c_inv_hd=>gt_credit_updates INTO DATA(ls_credit).
      UPDATE ztab_o2c_cust
        SET credit_exposure = credit_exposure - @ls_credit-amount
        WHERE customer_id = @ls_credit-customer_id.
    ENDLOOP.

    " Update Sales Order to Paid
    LOOP AT zbp_i_o2c_inv_hd=>gt_status_updates INTO DATA(ls_status).
      UPDATE ztab_o2c_hd
        SET overall_status = @ls_status-status
        WHERE order_id = @ls_status-order_id.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

---

### Step 5.4 — Expose Payments on the Invoice Object Page

In `ZI_O2C_INV_HD` CDS, add:

```abap
association [0..*] to ZI_O2C_PAY as _Payments
  on $projection.invoice_id = _Payments.invoice_id
```

In `ZC_O2C_INV_HD`, add facet:

```abap
{
  id: 'Payments',
  type: #LINEITEM_REFERENCE,
  label: 'Payment History',
  position: 30,
  targetElement: '_Payments'
},
```

---



---

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


