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
**Navigation**
⬅️ Previous: [[Phase_2]] | ⬆️ Back to [[O2C_IMPLEMENTATION_PLAN|Main Plan]] | Next: [[Phase_4]] ➡️
