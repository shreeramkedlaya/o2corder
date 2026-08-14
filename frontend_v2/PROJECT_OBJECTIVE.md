# O2C V2: Lifts & Escalators Project Objective

## The Final Goal
The objective is to build a dedicated Fiori App ("O2C Project Orders") specifically for project-based manufacturing, diverging from the standard 100%-on-delivery billing model.

When an end-user creates a Sales Order and adds a Lift material:
1. **Automation**: The backend automatically generates a 4-step Billing Plan (10% Advance, 30% Material Delivery, 40% Installation, 20% Testing) specific to that lift.
2. **Phase Assignment**: The user can select lifts and use an action button to assign them to specific delivery "Phases" (e.g., Phase 1 or Phase 2). 
3. **Milestone Invoicing**: In the UI's Billing Plan table, the user can select a specific milestone row (e.g., the 10% Advance row) and click a **"Raise Invoice"** button to generate an invoice *only* for that percentage amount.

## The Architecture Flow
This is the roadmap of how the backend is constructed to support the UI:

### 1. Data Foundation (Phase 1 & 2)
The raw `ZTAB_LFT_*` DDIC Tables store the persistent data. The `ZI_LFT_*` Interface CDS Views sit directly on top of them, linking the tables hierarchically (Header -> Item -> Billing Plan) using RAP compositions.

### 2. Projection & UI Layer (Phase 3)
The Projection Views (`ZC_LFT_*`) sit on top of the Interface views. In Fiori Elements V4, these views contain the `@UI...` annotations that dictate exactly how the frontend renders (e.g., defining columns, facets, and Action buttons).

### 3. The Brain / ABAP Class (Phase 4)
The Behavior Definition (`.bdef`) and its ABAP Implementation Class hold the transactional logic. This is where the 10/30/40/20 split logic is mathematically calculated and where the "Raise Invoice" button executes its backend updates.

### 4. The Connection (Phase 5)
The entire package is exposed via a Service Definition and OData V4 Service Binding (`ZUI_LFT_SO_V4`), which the `frontend_v2` UI5 application consumes.
