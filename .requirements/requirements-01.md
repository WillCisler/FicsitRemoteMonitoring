Thoroughly read and understand the PBIP knowledge base in the [kb-kql](../.resources/kb-kqlmd) file.

# Business Requirements 💼

Edit a KQL database for the use of the Ficsit team to analyze sales data streams. The database should be designed to meet the following business requirements:

| Requirement ID      | Description             | User Story                                                                                                                                                                                                                                                       | Expected Behavior                                                                                                                                                                                                                       |
| ------------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Engineering-001** | Power Network Analysis  | As a **Lead Pioneer**, I want to see power generation statistics over time and be able to analyse trends and resource bottlenecks quicky. My aim is that all power generators run at full efficiency                                                             | Create tables to enable this analysis alongside table update policies and functions to feed that data in real time.                                                                                                                     |
| **Engineering-002** | Power Grid Clean up     | As a **Lead Pioneer**, I want to clean the power network connections between sections of the grid to allow for better maintenance and upgrades anf the installation of priority switches. These allow the network to fail gracefully in the event of power cuts. | Create views of the power lines and grid connections to visualize and manage the network topology.                                                                                                                                      |
| **Engineering-003** | Produciton Optimisation | As a **Lead Pioneer**, I want to identify any machines that require tuning to maximise efficency.                                                                                                                                                                | Create views and table that show active factory machines with the lowest efficency. Create reference views that can help can guide a pioneer to the machine's location. Create a graph view of the prodcution lines to identify issues. |

# Data source information 🛢️

- **MCP Server**: `fabric-rti-mcp-in-ficsit`
- **Database**: `ficsit-data`

If you cannot connect to the KQL Server above to get the schema, all information of the Datawarehouse can be found in the file `..\FicsitRemote\.resources\schema.md`

# Development rules 🧑‍💻

- Analyze the datasource tables in `..\FicsitRemote\.resources\schema.md` and pick the tables that best answer the requirements. But dont create any tables or columns that are not strictly necessary, when in doubt ask me.
- use table policies to update the tables in real time, but do not create any table policies that are not strictly necessary.
- Use the KQL language to create the tables and policies, but do not use any KQL functions that are not strictly necessary.
- Make sure you set descriptions on all created objects using business language
- Ensure correct and consistent data types across all columns.For example, numeric fields used in calculations must not be stored as text and a column in a view should not have a different data type than the column in the table it is based on.
- Use the correct data types for each column, such as `datetime` for timestamps, `long` for large integers, and `real` for floating-point numbers.
- for the most part ignore the columns about the bounding box unless you find that they are necessary for the requirements.

# Naming conventions 🏷️

- be consistent with naming across all objects by using snake_case
- Use singular names for dimension tables
- Use plural names for fact tables
- All model object names should be lower case
- Use descriptive names for columns, such as `power_generation` instead of `gen`, and avoid abbreviations.
