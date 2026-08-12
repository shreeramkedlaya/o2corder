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


---

**Navigation**

⬅️ [Phase 3 — Fulfilment & Delivery](https://github.com/shreeramkedlaya/o2corder/wiki/Phase-3) &nbsp;&nbsp;🏠 [Home](https://github.com/shreeramkedlaya/o2corder/wiki) &nbsp;&nbsp; ➡️ [Phase 5 — Payment & Reconciliation](https://github.com/shreeramkedlaya/o2corder/wiki/Phase-5)
