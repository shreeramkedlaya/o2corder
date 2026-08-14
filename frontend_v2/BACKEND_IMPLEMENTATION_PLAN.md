# End-to-End Backend Implementation Plan (O2C V2)

This document outlines the detailed technical architecture for building the backend ABAP RESTful Application Programming (RAP) logic for the O2C V2 Application (Lifts & Escalators). 

Based on your architectural decision, we are building this in a **brand new top-level ABAP package** (`ZLOCAL_SK_LIFT`). This ensures 100% isolation from the original O2C flow. 

> **Important**: When creating these objects in ADT, use the exact **[Description]** provided below, as SAP mandatorily requires short texts for all new objects.

---

## 1. Package Creation
*   **Package**: `ZLOCAL_SK_LIFT`
    *   **Description**: `O2C V2 Project & Lifts Management`

---

## 2. Database Dictionary (DDIC) - New Package
We will create a fresh set of transparent tables.

*   **`ZTAB_LFT_HD` (Project Order Header)**
    *   **Description**: `Project Order Header Persistent Storage`
    *   Fields: `CLIENT`, `ORDER_ID`, `CUSTOMER_ID`, `GROSS_TOTAL`, `TAX_TOTAL`, `CURRENCY`, `STATUS`
*   **`ZTAB_LFT_IT` (Project Order Item)**
    *   **Description**: `Project Order Items Persistent Storage`
    *   Fields: `CLIENT`, `ORDER_ID`, `ITEM_POS`, `MATERIAL_ID`, `QUANTITY`, `ITEM_AMOUNT`, `TAX_RATE`, `TAX_AMOUNT`
*   **`ZTAB_LFT_BPLAN` (Billing Plan Milestones)**
    *   **Description**: `Billing Plan Milestones Persistent Storage`
    *   Fields: `CLIENT`, `ORDER_ID`, `ITEM_POS`, `MILESTONE_ID`, `MILESTONE_TYPE` (ADV, MAT, INS, TST), `PHASE_ID` (1 or 2), `PERCENTAGE`, `AMOUNT`, `STATUS` (P=Pending, I=Invoiced), `INVOICE_ID`, `DUE_DATE`
*   **`ZTAB_LFT_INV` (Invoice Header)**
    *   **Description**: `Project Invoice Header Persistent Storage`
    *   Fields: `CLIENT`, `INVOICE_ID`, `ORDER_ID`, `MILESTONE_ID`, `GROSS_AMOUNT`, `TAX_AMOUNT`, `DUE_DATE`

---

## 3. Core Data Services (CDS) Interface Layer
Create the foundational CDS views on top of your new tables.

*   **`ZI_LFT_HD`**
    *   **Description**: `Interface View for Project Order Header`
    *   Root view on `ZTAB_LFT_HD`. Includes composition to `ZI_LFT_IT`.
*   **`ZI_LFT_IT`**
    *   **Description**: `Interface View for Project Order Items`
    *   Item view on `ZTAB_LFT_IT`. Includes composition to `ZI_LFT_BPLAN`.
*   **`ZI_LFT_BPLAN`**
    *   **Description**: `Interface View for Billing Plan Milestones`
    *   View on `ZTAB_LFT_BPLAN`. Association back to `ZI_LFT_IT`.
*   **`ZI_LFT_INV`**
    *   **Description**: `Interface View for Project Invoices`
    *   View on `ZTAB_LFT_INV`.

---

## 4. RAP Behavior Definition (BDEF)
Map out the complex business logic (the 10/30/40/20 rule) in your new package.

*   **Behavior Definition `ZI_LFT_HD`**
    *   **Description**: `Behavior for Project Order Management`

### 4.1 Determinations (Automated Logic)
*   `calculateTaxes` (On Modify of Item Price/Quantity): Calculates GST and rolls it up to the header.
*   `generateMilestones` (On Save of Item): When an item is added, automatically insert the 4 milestone rows (10%, 30%, 40%, 20%) into `ZTAB_LFT_BPLAN` with `STATUS` = 'P'.

### 4.2 Actions (User Buttons)
*   **Abstract Entity Popup**: `ZABS_LFT_PHASE_INPUT` 
    *   **Description**: `Abstract Entity for Phase Delivery Input`
*   **Action `createPhaseDelivery`** (On `ZI_LFT_HD`): Uses the popup. Group the specified lifts into a delivery status and unlocks the 30% Milestone rows.
*   **Action `generateInvoice`** (On `ZI_LFT_BPLAN`): Reads the selected milestone row, inserts a new record into `ZTAB_LFT_INV`, sets `DUE_DATE` to +7 days, and updates the milestone status to 'I'.

---

## 5. Projection Layer & UI Annotations
Expose the behavior for your new `frontend_v2` Fiori Elements app.

*   **`ZC_LFT_HD`**
    *   **Description**: `Projection View for Project Order Header`
    *   Add `@UI.facet` to show order header details.
*   **`ZC_LFT_IT`**
    *   **Description**: `Projection View for Project Order Items`
    *   Add `@UI.facet` to show the nested Billing Plan table (`ZC_LFT_BPLAN`).
*   **`ZC_LFT_BPLAN`**
    *   **Description**: `Projection View for Billing Plan Milestones`
    *   Add `@UI.lineItem` annotations to display Percentage, Amount, Status. Add `@UI.lineItem: [{ type: #FOR_ACTION, dataAction: 'generateInvoice', label: 'Raise Invoice' }]`.

---

## 6. Service Definition & Binding
Publish the endpoint for the `frontend_v2` app to consume.

*   **Service Definition `ZUI_LFT_SO_V4`**
    *   **Description**: `Service Definition for Project Orders`
    *   Expose `ZC_LFT_HD`, `ZC_LFT_IT`, `ZC_LFT_BPLAN`.
*   **Service Binding `ZUI_LFT_SO_V4_O4`**
    *   **Description**: `OData V4 Binding for Project Orders`
    *   Bind as OData V4 and publish.

---

## ✅ Execution Checklist
Use this checklist to track your development progress in your new ABAP package:

### Phase 1: Data Dictionary (New Package)
- [x] Create new top-level package `ZLOCAL_SK_LIFT` in Eclipse ADT.
- [x] Create `ZTAB_LFT_HD` and `ZTAB_LFT_IT` tables.
- [x] Create `ZTAB_LFT_INV` table.
- [x] Create new transparent table `ZTAB_LFT_BPLAN`.

### Phase 2: Interface CDS Views
- [x] Create `ZI_LFT_HD` and `ZI_LFT_IT`.
- [x] Create `ZI_LFT_BPLAN`.
- [x] Establish compositions between Header -> Item -> Billing Plan.

### Phase 3: RAP Behavior (BDEF & Implementation Class)
- [ ] Define `ZI_LFT_HD` behavior (Draft handling, late numbering).
- [ ] Implement `calculateTaxes` determination in ABAP class.
- [ ] Implement `generateMilestones` determination (10/30/40/20 logic).
- [ ] Create abstract entity `ZABS_LFT_PHASE_INPUT`.
- [ ] Implement `createPhaseDelivery` action logic.
- [ ] Implement `generateInvoice` action on the BPLAN entity.

### Phase 4: Projections & UI
- [x] Create `ZC_LFT_HD` with UI Header Facets.
- [x] Create `ZC_LFT_IT` with UI Item Facets.
- [x] Create `ZC_LFT_BPLAN` with UI Line Items and Action Buttons.

### Phase 5: Service & Deployment
- [x] Create Service Definition `ZUI_LFT_SO_V4`.
- [x] Create Service Binding (OData V4) and publish.
- [x] Update `frontend_v2/webapp/manifest.json` locally to point to this new service URI!
