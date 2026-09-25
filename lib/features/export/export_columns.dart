/// Column headers of every exported table — shared by the exporter
/// (`export_rows.dart`) and the CSV importer (`features/import/`), so the
/// two can never drift apart (like one shared schema file for a form and
/// its API). Pure Dart: no Flutter, no database.
library;

/// One row per fuel line; the refueling's own columns repeat on each line.
const refuelingExportHeaders = [
  'Vehicle',
  'Date',
  'Time',
  'Odometer',
  'Fuel',
  'Tank',
  'Price/Unit',
  'Volume',
  'Line Total',
  'Full Tank',
  'Missed Previous',
  'Gas Station',
  'Payment Method',
  'Reason',
  'Driver',
  'Discount',
  'Total Cost',
  'Currency',
  'Notes',
];

/// Expense, Service and Income: one row per typed item; the entry's own
/// columns repeat on each item.
const entryExportHeaders = [
  'Vehicle',
  'Date',
  'Time',
  'Odometer',
  'Title',
  'Type',
  'Item Amount',
  'Part Number',
  'Place',
  'Payment Method',
  'Reason',
  'Driver',
  'Discount',
  'Installment No',
  'Installment Count',
  'Total Cost',
  'Currency',
  'Notes',
];

const routeExportHeaders = [
  'Vehicle',
  'Mode',
  'Origin',
  'Start Date',
  'Start Time',
  'Start Odometer',
  'Destination',
  'End Date',
  'End Time',
  'End Odometer',
  'Value/Distance',
  'Total',
  'Cargo Type',
  'Contractor',
  'Cargo Unit',
  'Cargo Amount',
  'Cargo Weight',
  'Cargo Volume',
  'Freight Value',
  'Installments',
  'Driver',
  'Reason',
  'Currency',
  'Notes',
];

const readingExportHeaders = [
  'Vehicle',
  'Date',
  'Time',
  'Odometer',
  'Driver',
  'Notes',
];

const checklistExportHeaders = [
  'Vehicle',
  'Date',
  'Time',
  'Odometer',
  'Form',
  'OK',
  'Problems',
  'Problem Items',
  'Driver',
  'Notes',
];

const reminderExportHeaders = [
  'Vehicle',
  'Target',
  'Type',
  'Repeat',
  'By Distance',
  'Due Odometer',
  'Every Distance',
  'By Date',
  'Due Date',
  'Every Amount',
  'Every Unit',
  'Last Done Odometer',
  'Last Done Date',
  'Active',
  'Notes',
];

/// Date and time cell formats (`intl` `DateFormat` patterns). Numbers are
/// written with `double.toString()` (dot decimal, no grouping, whole
/// numbers without `.0`); booleans as `Yes`/`No`; enums by their Dart name.
const exportDatePattern = 'yyyy-MM-dd';
const exportTimePattern = 'HH:mm';
