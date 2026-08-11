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
**Navigation**
⬅️ Previous: [[Phase_0_Overview]] | ⬆️ Back to [[O2C_IMPLEMENTATION_PLAN|Main Plan]] | Next: [[Phase_2]] ➡️
