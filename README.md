# O2C Sales Order Management (Fiori Elements V4)

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

## 🚀 Getting Started
1. Clone the repository to your local machine.
2. Run `npm install` to install Fiori tools and dependencies.
3. Run `npm start` to serve the application connected to your SAP backend.
   *(Alternatively, run `npm run start-mock` to test the UI using local mock data).*
