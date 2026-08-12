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


---

**Navigation**

⬅️ [Phase 4 — Billing & Accounts Receivable](https://github.com/shreeramkedlaya/o2corder/wiki/Phase-4) &nbsp;&nbsp;🏠 [Home](https://github.com/shreeramkedlaya/o2corder/wiki) &nbsp;&nbsp; ➡️ [Phase 6 — UI & Dashboard Analytics](https://github.com/shreeramkedlaya/o2corder/wiki/Phase-6)
