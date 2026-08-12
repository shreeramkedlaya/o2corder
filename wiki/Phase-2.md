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


---

**Navigation**

⬅️ [Phase 1 — Master Data Foundation](https://github.com/shreeramkedlaya/o2corder/wiki/Phase-1) &nbsp;&nbsp;🏠 [Home](https://github.com/shreeramkedlaya/o2corder/wiki) &nbsp;&nbsp; ➡️ [Phase 3 — Fulfilment & Delivery](https://github.com/shreeramkedlaya/o2corder/wiki/Phase-3)
