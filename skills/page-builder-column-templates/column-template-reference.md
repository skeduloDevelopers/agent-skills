## Overview

Use Skedulo's templating engine to enhance the data displayed in a list view. Column templates support HTML. JavaScript is not supported.

## Edit the column template

To edit a column template:

1. Navigate to **Settings > Data management > Objects & fields**.
2. Select a data object. For example, *Jobs*.
3. Click **Edit default columns** in the top right-hand corner of the screen to display the **Edit default columns** page.
4. Click ![Edit column button](/images/customization/Edit-column-button.png) **Edit column** beside the name of the column you want to edit.
   
   ![The location of the Edit column button](/images/customization/Edit-column-button-location.png)

5. In the **Edit column** modal, update the **Column template** using the examples in this article. You can change the styling, format numbers, or add a hyperlink.
6. Click **Done** to close the modal and view your changes in the **Table preview** window.
7. Click **Save**.

### Cross-object fields

Retrieve related data based on a lookup or relationship on the primary object. Prefix the field name with the cross-object name. For example, to display the related account's billing city on a work item list view, update the column template to:

```html
{{ Account.BillingCity }}
```

### Styling

- Bold: `<b>{{ FieldName }}</b>`
- Italics: `<i>{{ FieldName }}</i>`
- Underscore: `<u>{{ FieldName }}</u>`
- Color: `<span style="color: #HEX-CODE;">{{ FieldName }}</span>`

### Hyperlinks

The `brz-link` component renders hyperlinks and supports standard anchor attributes (`href`, `target`, and `rel`).

There are two link types: *Primary* and *Secondary*. Use the `link-type` property to set which one is used.

```html
<brz-link href="url"> Primary link text </brz-link>
<brz-link href="url" link-type="secondary"> Secondary link text </brz-link>
```

In this example, `linkurl` provides the URL and the `name` field provides the link text:

```html
<brz-link href="{{ linkurl }}"> {{ name }} </brz-link>
```

![edit column modal with hyperlink example](/images/customization/adv-column-config-hyperlink.png)

Hyperlinks can be relative so they work across multiple team names without requiring a hardcoded `https://team-name.my.skedulo.com` prefix. For example:

```html
<brz-link href="/job/{{ UID }}">Job</brz-link>
```

Any field on the object can be merged into the hyperlink template, including custom fields. This lets you construct custom target URLs and generate dynamic link text. For example, to use the `Name` field as the link text instead of a static value:

```html
<brz-link href="/job/{{ UID }}">{{ Name }}</brz-link>
```

![merging fields in a hyperlink](/images/customization/mceclip1.png)

#### Linking to another page within an object

To link to another page associated with your object, use the `buildPlatformUrl` callback. For example, to add a link to each row's edit page:

```html
<brz-link href="{{_.host.buildPlatformUrl( 'invoice-edit?uid=' + _.record.primaryKeyValue )}}">Edit</brz-link>
```

![The Table preview overlaid with the Edit column modal showing the hyperlink code entered](/images/customization/adv-column-config-hyperlinks.png)

Use `buildPlatformUrl` in place of `/platform/page/` to link to a page using its slug alone. If the `/platform/page/` path changes, the link still resolves as long as the slug remains the same.


### Concatenation

Merge multiple fields within a column template using the following syntax:

```html
{{Field_One}} {{Field_Two}} {{Field_n}}
```

You can also apply styling when concatenating fields. For example, the following produces "**JOB-0526** - (Repair)" in a single column:

```html
<b>{{ Name }}</b> - ({{ Type }})
```

### If statements

If statements evaluate a condition and display content based on the result. When the condition is true, the first block displays; otherwise, the second block displays. You can also specify alternate conditions with `elseif`.

For example, to check whether the `Type` field is populated — displaying the field value if true, or `Not set` if false:

```html
{% if Type %}

{{ Type }} 

{% else %}

"Not set" 

{% endif %}
```

Use `elseif` to evaluate multiple conditions with different styling for each. For example:

```html
{% if Type == "Repair" %} {# Check if the Type is equal to "Repair" #}

<b>{{ Type }}</b> {# If true, display the field value in bold #}

{% elseif Type == "Installation" %}{# Check if the Type is equal to "Installation" #}

<i>{{ Type }}</i> {# If true display the field value in italics #}

{% else %} {# otherwise #}

{{ Type }} {# display the field value with no additional styling #}

{% endif %} {# Closes the if statement #}
```

### Expressions

You can use many types of literal expressions. For example:

- Strings: `"How are you?"`, `'How are you?'`
- Numbers: `40`, `30.123`
- Arrays: `[1, 2, "array"]`
- Dicts: `{ one: 1, two: 2 }`
- Boolean: `true`, `false`

### Math

Perform mathematical operations within list view cells. Use math sparingly — results are not stored in the database, so users cannot filter or sort on calculated values. The following operators are available:

- Addition: `+`
- Subtraction: `-`
- Division: `/`
- Division and integer truncation: `//`
- Division remainder: `%`
- Multiplication: `*`
- Power: `**`

For example, to display the cost of a work item based on scheduled duration, where a custom field stores the *Rate* value on the object:

```html
{{ Duration * Rate }}
```

### Comparisons

- Equals: `==`
- Equals (strict): `===`
- Not equal to: `!=`
- Not equal to (strict): `!==`
- Greater than: >
- Greater than or equal to: `>=`
- Less than: `<`
- Less than or equal to: `<=`

For example:

```html
{% if Duration > 60 %}

Extended appointment

{% else %}

Standard appointment

{% endif %}
```

### Logic

- and: `and`
- or: `or`
- not: `not`
- Use parentheses to group expressions.

### Number formatting

Use the `number` function to format numbers for display. Control how many decimal places are shown — Skedulo rounds any trailing decimals.

For example, to round all numbers in a column to two decimal places:

```html
{{ Total | number(decimals=2) }}
```

### Currency

To add a currency symbol to a number column, enter the symbol directly before the template expression when editing the column template. For example, to display the *Cost per day* column in dollars:

```html
${{ Costperday |number(decimals=2) }}
```

This renders as:

![currency rendered example](/images/customization/CurrencyRendered.png)

### Percentage

To display a number as a percentage, add `%` after the expression. For example, to display the *Amount Paid* field with a percentage symbol:

```html
{{ amountpaid}}%
```

This renders as:

![percentage rendered example](/images/customization/column-config-percentage.png)

### Date formatting

Date and date/time values are stored in UTC format. Displayed directly, they show as a raw UTC string — for example, `2021-02-19T16:00:00.000Z`. Use the following format modifiers to display a readable value.

|  | Modifier | Output |
| --- | --- | ---|
| **Day** | `D` | 1 ... 5, 6 |
|  | `do` | 1st, 5th, 6th |
|  | `dd` | Su, Mo ... Fri, Sa |
|  | `ddd` | Sun |
|  | `dddd` | Sunday, Monday ... Friday, Saturday |
|  |  |  |
| **Month** | `M`| 1, 2 ... 11, 12 |
|  | `Mo` | 1st, 2nd ... 11th, 12th |
|  | `MM` | 01, 02 ... 11, 12 |
|  | `MMM` | Jan, Feb ... Nov, Dec |
|  | `MMMM` | January, February ... November, December |
|  |  |  |
| **Year** | `YY` | 20, 21 ... 24, 25 |
|  | `YYYY` | 2020, 2021 ... 2024, 2025 |
|  |  |  |
| **Quarter** | `Q` | 1, 2, 3, 4 |
|  | `Qo` | 1st, 2nd, 3rd, 4th |
|  |  |  |
| **AM/PM** | `A` | AM, PM |
|  | `a` | am, pm |
|  |  |  |
| **Hour** | `H` | 0, 1 ... 22, 23 |
|  | `HH` | 00, 01 ... 22, 23 |
|  | `h` | 1, 2 ... 11, 12 |
|  | `hh` | 01, 02 ... 11, 12 |
|  | `k` | 1, 2 ... 23, 24 |
|  | `kk` | 01, 02 ... 23, 24 |
|  |  |  |
| **Minute** | `m` | 0, 1 ... 58, 59 |
|  | `mm` | 00, 01 ... 58, 59 |
|  |  |  |
| **Timezone** | `z` | BST, CET, GMT |

For example:

```html
{{ CreatedDate | date("ddd D MMM YYYY") }}
```

![date format example one](/images/customization/adv-column-config-date1.png)

```html
{{ CreatedDate | date("ddd D MMM YYYY h:mma") }}
```

![date format example two](/images/customization/adv-column-config-date2.png)

```html
{{ CreatedDate | date("ddd D MMM YYYY h:mma (z)") }}
```

![date format example three](/images/customization/adv-column-config-date3.png)

### Time formatting

To isolate the time portion of a date/time field, use only time format tokens. For example:

```html
{{ CreatedDate | date("h:mma (z)") }}
```

![timezone time only](/images/customization/adv-column-config-time-only.png)

#### Timezone manipulation

By default, all date/time values are adjusted from UTC to the timezone of the device accessing Skedulo. In some cases, you may need to display a date/time in a different timezone — for example, to show when a work item takes place in the customer's region rather than the dispatcher's local time.

You can configure any date/time field to display in any valid timezone. For example:

```html
{{ Start | date("tz", Region.Timezone) }}
```

```html
{% if Start %}

{% set tzStart = Start | date("tz", Region.Timezone) %}
{% set tzEnd = End | date("tz", Region.Timezone) %}

{{ tzStart| date("ddd D MMM YYYY") }}, </br> 
{{ tzStart|date("h:mma") }} - {{ tzEnd|date("h:mma (z)") }} 

{% else %}
<span style="color: #7d879c;">Not Set</span> 

{% endif %}
```

### Multi-select picklist fields

If you have a field that allows the selection of multiple options, you can choose to truncate or wrap the text to prevent columns from becoming too wide.

#### Wrapping text

To display each value on a new line, enter the following in the **Column template** field, where `category` is the field name:

```html
<ul> {% for item in category %} 
<li>{{item}}</li>
{% endfor %} </ul>
```

To display each value as a lozenge on a new line, enter the following in the **Column template** field, where `category` is the field name:

```html
{% for item in category %}<brz-lozenge style="margin: var(--sp-spacing-1)" theme="subtle" color="neutral">{{item}}</brz-lozenge>{% endfor %}
```

To number values and display them on new lines, enter the following in the **Column template** field, where `category` is the field name:

```html
<ul>
{% for item in category %}
<li>{{loop.index}} {{item}}</li>
{% endfor %}
</ul>
```

#### Truncating text

To limit the characters displayed in a multi-picklist field — for example, to 50 characters — enter the following in the **Column template** field, where `category` is the field name:

```html
{% if category %}{{ category | string | truncate(50, "...")}}{% endif %}
```

### Lozenges

Use the Breeze UI lozenge component, `brz-lozenge`, to highlight status or state. For example:

```html
<brz-lozenge>{{status}}</brz-lozenge>
```

![default lozenge example](/images/customization/Lozenge-default-example.png)

#### Lozenge sizes

Lozenges support different sizes using the `size` property: `small`, `medium`, and `large`. The default is `medium`. For example:

```html
<brz-lozenge size="small">Small lozenge</brz-lozenge>

<brz-lozenge size="medium">Medium lozenge</brz-lozenge>

<brz-lozenge size="large">Large lozenge</brz-lozenge>
```

![example of lozenge sizes](/images/customization/lozenge-sml-med-lg-example.png)

#### Supporting icons

Render a lozenge with an icon using the `leading-icon` property. For example, to display a different icon for each status value:

```html
{% if status == "Paid" %}
<brz-lozenge leading-icon="tick">{{status}}</brz-lozenge>

{% elseif status == "Sent" %}
<brz-lozenge leading-icon="notify">{{status}}</brz-lozenge>

{% elseif status == "Overdue" %}
<brz-lozenge leading-icon="warning">{{status}}</brz-lozenge>

{% else %} {{ status }}

{% endif %}
```

![example of icons in lozenges](/images/customization/Lozenge-icon-example.png)

A full list of available icons is in the [Design system documentation](https://skedulo.github.io/breeze-ui/?path=/docs/breeze-tokens-icons--docs).

### Current user

Display different data based on the currently logged-in user. Available fields vary depending on how the `Users`, `Resources`, and `PrimaryRegion` objects are configured for your team, but the default fields are:

| Object | Fields |
| --- | --- |
| Users | `City`, `Country`, `CreatedById`, `CreatedDate`, `Email`, `FirstName`, `FullPhotoUrl`, `IsActive`, `LastModifiedById`, `LastModifiedDate`, `LastName`, `MobilePhone`, `Name`, `PostalCode`, `SmallPhotoUrl`, `State`, `Street`, `UID`, `UserTypes`, `Roles`, `messaging_beta_access` |
| Resources | `Alias`, `AutoSchedule`, `Category`, `CountryCode`, `CreatedById`, `CreatedDate`, `Date`, `Email`, `EmploymentType`, `GeoLatitude`, `GeoLongitude`, `HomeAddress`, `IsActive`, `LastModifiedById`, `LastModifiedDate`, `MobilePhone`, `Name`, `Notes`, `NotificationType`, `Number`, `PrimaryPhone`, `PrimaryRegionId`, `Rating`, `ResourceActivityId`, `ResourceLookupId`, `ResourceType`, `Text`, `UID`, `UserId`, `WeeklyHours`, `WorkingHourType`, `ResourceAvatar`, `User` |
| PrimaryRegion | `Timezone`, `Description`, `Radius`, `LastModifiedDate`, `LastModifiedBy`, `CreatedBy`, `GeoLatitude`, `almost_clear`, `covid_case_count`, `GeoLongitude`, `Name`, `CreatedById`, `CreatedDate`, `CountryCode`, `LastModifiedById`, `UID` |

#### Use cases

Access these fields using `$CurrentUser` in column templates. For example:

* Region
  
  `{{ $CurrentUser.Resources[0].PrimaryRegion.Name }}`
  
  On an if condition:

  `{% if $CurrentUser.Resources[0].PrimaryRegion.Name == Job.Region.Name %} X {% else %} Y {% endif %}`

* Category
  
  `{{ $CurrentUser.Resources[0].Category }}`

* Type
  
  `{{ $CurrentUser.UserTypes }}`
