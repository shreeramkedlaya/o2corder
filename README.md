# O2C Sales Order Management (Fiori Elements V4)

![ABAP RAP](https://img.shields.io/badge/ABAP-RAP%20Strict%20Mode-0070F3?style=flat&logo=sap&logoColor=white)
![Fiori Elements](https://img.shields.io/badge/SAP-Fiori%20Elements%20V4-009BAA?style=flat&logo=sap&logoColor=white)
![OData V4](https://img.shields.io/badge/OData-V4-orange?style=flat)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=flat)
![Phases](https://img.shields.io/badge/Phases-7%20%2F%207-blueviolet?style=flat)
<!-- ![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat) -->

A modern SAP Fiori Elements application for Order-to-Cash (O2C) Sales Order Management, built using OData V4 and the ABAP RESTful Application Programming (RAP) model.

## ✨ Features
- **End-to-End O2C Flow:** Manage Sales Orders, Logistics (Deliveries), and Finance (Invoicing & Payments) in a single unified application.
- **Draft Capabilities:** Edit, save, and resume Sales Orders seamlessly without losing data utilizing the RAP transactional draft buffer.
- **Dynamic Price Orchestration:** Automatic calculation of item amounts and header grand totals via backend ABAP determinations.
- **Early Numbering:** Automated generation of IDs (`ORD-`, `DEL-`, `INV-`) with robust duplicate-key avoidance across active and draft tables.
- **Strict Mode Operations:** Direct database updates (like Credit Exposure adjustments and Stock reductions) safely deferred to the Saver Class (`save_modified`) phase.
- **Cross-BO Navigation:** Seamlessly navigate between independent Business Objects via Fiori Object Page Facets.

## 🏗️ Technical Architecture
- **Frontend:** SAP Fiori Elements (OData V4)
- **Backend:** ABAP RAP (RESTful Application Programming Model)
- **Database:** SAP HANA / ABAP Environment

## 📖 Implementation Documentation

The full implementation guide is split into phase-by-phase documents:

| Phase | Topic | Description |
|-------|-------|-------------|
| [Phase 0](https://github.com/shreeramkedlaya/o2corder/wiki) | 🗺️ Overview & Architecture | Document chain, RAP stack pattern & DB design |
| [Phase 1](https://github.com/shreeramkedlaya/o2corder/wiki#phase-1---master-data-foundation) | 🛠️ Master Data Foundation | Customer & Material master tables and value helps |
| [Phase 2](https://github.com/shreeramkedlaya/o2corder/wiki#phase-2---order-header-enhancements-stages-1--2) | 📦 Sales Order Core | Header & Item CRUD with draft, early numbering |
| [Phase 3](https://github.com/shreeramkedlaya/o2corder/wiki#phase-3---fulfilment--delivery-stages-3--4) | ⚙️ Logistics & Fulfilment | createDelivery, postGoodsIssue, stock deduction |
| [Phase 4](https://github.com/shreeramkedlaya/o2corder/wiki#phase-4---billing--accounts-receivable-stages-5--6) | 🧾 Billing & AR | createInvoice, AR status, due date, credit exposure |
| [Phase 5](https://github.com/shreeramkedlaya/o2corder/wiki#phase-5---payment--reconciliation-stage-7) | 💳 Payments & Reconciliation | postPayment, clearing invoices, order lifecycle close |
| [Phase 6](https://github.com/shreeramkedlaya/o2corder/wiki#phase-6---ui--dashboard-analytics) | 📊 UI & Dashboard Analytics | Fiori UI annotations, facets & reporting |

> See also: [Gap Analysis](o2c_gap_analysis.md) · [O2C Flowchart](o2c&#32;flowchart.mermaid) · [Full Wiki](../../wiki)

## 🚀 Getting Started
1. Clone the repository to your local machine.
2. Run `npm install` to install Fiori tools and dependencies.
3. Run `npm start` to serve the application connected to your SAP backend.
   *(Alternatively, run `npm run start-mock` to test the UI using local mock data).*
