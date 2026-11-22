# 01 - Business Case Study: Technical Support Operations Data Warehouse

## The company
A managed IT services provider in Egypt supports about 200 business customers (fictional data). Customers raise **tickets**; support **agents** work on them; each ticket moves through a **workflow** (Created, Assigned, In Progress, Pending Customer, Escalated, Resolved, Closed, Reopened, Cancelled) and accumulates **breakdown events** - individual pieces of technical work with effort (minutes) and cost (EGP). Operations also records a sparse **stability observation** for each customer (very stable ... very unstable).

You have already worked with this data in the SQL Case Study: you wrote queries against the operational tables. In this project you play the **data integration engineer**. Management wants a reliable **data warehouse** that is refreshed from files and from the operational database, every day, without anyone babysitting it.

## What management wants to be able to answer
- How many tickets are created, resolved, reopened - per customer, segment, region, month?
- How long does it take to resolve a ticket (first resolution), and how often is a ticket reopened?
- Where does technical effort and cost go: by category, component, ticket type, agent team?
- What is the status of the ticket, the stability of the customer and the owner of the ticket **at the moment** each piece of work was done?
- How do customers look **as they were at the time** (a customer that moved from Cairo to Giza must keep its old tickets in Cairo)?

## Why this needs ETL (and SSIS)
| Problem | What the pipeline must do |
|---|---|
| Data arrives as CSV files in daily/weekly batches | Read files, validate, load staging, reconcile counts |
| Feeds contain dirty rows | Detect, redirect, log with a reason, keep loading |
| The source database and the report model have different shapes | Migrate and reshape into a star schema |
| Customers change over time | Slowly changing dimensions: Type 1 (overwrite) and Type 2 (history) |
| New batches contain new, changed and repeated rows | Incremental loading, safe to rerun |
| Nobody should start packages by hand | Schedule, log, fail loudly, recover |

## Your deliverables (six labs)
1. Flat files into SQL Server staging 2. Cleansing, transformation and rejects 3. Database migration and warehouse (star schema) load 4. SCD Type 1 / Type 2 5. Incremental loading and reprocessing 6. Scheduling, logging, production readiness.

## Ground rules
- This is a **training** scenario with **synthetic** data. Nothing here is real customer information.
- The computer clock never decides business dates. Every batch has an explicit processing date and cutoff.
- Original source files are never edited. Fix problems in the pipeline, not in the data.
- SSIS is for the data movement and transformation. T-SQL is allowed for what is better done set-based (staging clean-up, merges, validation) - the labs say where.
- You will not find finished packages, expected row counts or solution queries in this package. You prove your own work with reconciliation (counts, sums, invariants).
