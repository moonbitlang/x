# Decimal

Arbitrary precision decimal type for exact decimal arithmetic in MoonBit.

## Overview

The `Decimal` type provides exact decimal arithmetic without floating-point errors, making it ideal for financial calculations and other applications requiring precise decimal representation.

## Key Features

- **Exact Precision**: No floating-point rounding errors
- **Arbitrary Scale**: Non-negative scale (no fixed upper bound)
- **BigInt Backend**: Uses `BigInt` for coefficient storage
- **Financial Safe**: Perfect for monetary calculations
- **JSON Support**: Built-in serialization/deserialization
- **Comprehensive API**: All standard arithmetic operations

## Basic Usage

```moonbit
test {
  // Create decimals from strings
  let price = match @decimal.Decimal::from_string("19.99") {
    None => @decimal.zero()
    Some(d) => d
  }
  let tax_rate = match @decimal.Decimal::from_string("0.08") {
    None => @decimal.zero()
    Some(d) => d
  }

  // Perform exact arithmetic
  let tax = price * tax_rate
  let total = price + tax

  // Round for currency display
  let total_rounded = match total.round(2) {
    Some(d) => d
    None => @decimal.zero()
  }

  inspect(total_rounded.to_string(), content="21.59")
}
```

## Creating Decimals

```moonbit
test {
  // From string (recommended for user input)
  let d1 = match @decimal.Decimal::from_string("123.45") {
    Some(d) => d
    None => @decimal.zero()
  }

  // From integers
  let d2 = @decimal.Decimal::from_int(42)

  // From BigInt
  let d3 = @decimal.Decimal::from_bigint(12345678901234567890N)

  // From double (with precision loss warning)
  let d4 = match @decimal.Decimal::from_double(3.14159, 5) {
    Some(d) => d
    None => @decimal.zero()
  }

  // Constants
  let zero = @decimal.zero()
  let one = @decimal.one()
  let neg_one = @decimal.neg_one()
  
  // Use variables to avoid warnings
  inspect(d1.to_string(), content="123.45")
  inspect(d2.to_string(), content="42")
  inspect(d3.to_string(), content="12345678901234567890")
  inspect(d4.to_string(), content="3.14159")
  inspect(zero.to_string(), content="0")
  inspect(one.to_string(), content="1")
  inspect(neg_one.to_string(), content="-1")
}
```

## Arithmetic Operations

```moonbit
test {
  let a = match @decimal.Decimal::from_string("123.45") {
    Some(d) => d
    None => @decimal.zero()
  }
  let b = match @decimal.Decimal::from_string("67.89") {
    Some(d) => d
    None => @decimal.zero()
  }

  // Basic operations
  let sum = a + b        // 191.34
  let diff = a - b       // 55.56
  let product = a * b    // 8381.0205
  let quotient = a / b   // 1.8183826778612461334511710119

  // Unary operations
  let neg_a = -a         // -123.45
  let abs_a = a.abs()    // 123.45
  
  // Use variables to avoid warnings
  inspect(sum.to_string(), content="191.34")
  inspect(diff.to_string(), content="55.56")
  inspect(product.to_string(), content="8381.0205")
  inspect(quotient.to_string(), content="1.8183826778612461334511710119")
  inspect(neg_a.to_string(), content="-123.45")
  inspect(abs_a.to_string(), content="123.45")
}
```

### Division scale and rounding

- Operator `/` uses a built-in `DEFAULT_SCALE` (currently 28) with HalfUp rounding.
- If you need a different scale or rounding strategy, use `Decimal::divide`.

```moonbit
test {
  let a = match @decimal.Decimal::from_string("1") {
    Some(d) => d
    None => @decimal.zero()
  }
  let b = match @decimal.Decimal::from_string("3") {
    Some(d) => d
    None => @decimal.zero()
  }

  // 4 decimal places, HalfUp rounding
  let q = match a.divide(b, 4, HalfUp) {
    Some(d) => d
    None => @decimal.zero()
  }
  inspect(q.to_string(), content="0.3333")

  // Default scale with HalfEven rounding
  let q2 = match a.divide(b, @decimal.DEFAULT_SCALE, HalfEven) {
    Some(d) => d
    None => @decimal.zero()
  }
  inspect(q2.scale(), content="28")
}
```

#### Rounding modes

`RoundingMode` supports:

- `HalfUp`: Round to nearest, ties away from zero
- `HalfEven`: Round to nearest, ties to even
- `Down`: Round towards zero
- `Up`: Round away from zero

## Comparison and Properties

```moonbit
test {
  let d = match @decimal.Decimal::from_string("123.45") {
    Some(d) => d
    None => @decimal.zero()
  }

  // Properties
  assert_true(d.is_positive())
  assert_false(d.is_zero())
  assert_false(d.is_negative())
  inspect(d.signum(), content="1")

  // Comparison
  let other = match @decimal.Decimal::from_string("67.89") {
    Some(d) => d
    None => @decimal.zero()
  }
  assert_true(d > other)
  assert_true(d >= other)
  assert_false(d == other)
}
```

## Rounding and Scaling

```moonbit
test {
  let d = match @decimal.Decimal::from_string("3.14159") {
    Some(d) => d
    None => @decimal.zero()
  }

  // Round to 2 decimal places (HalfUp by default)
  let rounded = match d.round(2) {
    Some(d) => d
    None => @decimal.zero()
  }
  inspect(rounded.to_string(), content="3.14")

  // Round (standard rounding)
  let rounded = match d.round(2) {
    Some(d) => d
    None => @decimal.zero()
  }
  inspect(rounded.to_string(), content="3.14")

  // Truncate to 2 decimal places
  let truncated = match d.truncate(2) {
    Some(d) => d
    None => @decimal.zero()
  }
  inspect(truncated.to_string(), content="3.14")

  // Scale to 4 decimal places (truncates by default)
  let scaled = match d.scale_to(4) {
    Some(d) => d
    None => @decimal.zero()
  }
  inspect(scaled.to_string(), content="3.1415")

  // Scale to 2 decimal places (truncates)
  let scaled = match d.scale_to(2) {
    Some(d) => d
    None => @decimal.zero()
  }
  inspect(scaled.to_string(), content="3.14")
}
```

## Conversion

```moonbit
test {
  let d = match @decimal.Decimal::from_string("123.45") {
    Some(d) => d
    None => @decimal.zero()
  }

  // To string
  inspect(d.to_string(), content="123.45")

  // To integer (truncates)
  let int_val = d.to_int()
  inspect(int_val, content="Some(123)")

  // To BigInt (truncates)
  let bigint_val = d.to_bigint()
  inspect(bigint_val, content="123")

  // To double (may lose precision)
  let double_val = d.to_double()
  inspect(double_val, content="123.45")
}
```

## JSON Serialization

```moonbit
test {
  let d = match @decimal.Decimal::from_string("123.45") {
    Some(d) => d
    None => @decimal.zero()
  }

  // To JSON
  let json = d.to_json()
  inspect(json, content="String(\"123.45\")")

  // From JSON
  let json_str = Json::string("67.89")
  let parsed : @decimal.Decimal = @json.from_json(json_str)
  inspect(parsed.to_string(), content="67.89")
}
```

## Financial Example

```moonbit
test {
  // Calculate compound interest
  let principal = match @decimal.Decimal::from_string("1000.00") {
    Some(d) => d
    None => @decimal.zero()
  }
  let rate = match @decimal.Decimal::from_string("0.05") {
    Some(d) => d
    None => @decimal.zero()
  } // 5% annual rate
  let years = 3

  // Simple interest calculation (compound interest would need power function)
  let interest = principal * rate * @decimal.Decimal::from_int(years)
  let amount = principal + interest

  let amount_rounded = match amount.round(2) {
    Some(d) => d
    None => @decimal.zero()
  }
  let interest_rounded = match interest.round(2) {
    Some(d) => d
    None => @decimal.zero()
  }
  
  inspect(amount_rounded.to_string(), content="1150.00")
  inspect(interest_rounded.to_string(), content="150.00")
}
```

## Error Handling

```moonbit
test {
  // Invalid string parsing
  let invalid = @decimal.Decimal::from_string("abc")
  inspect(invalid, content="None")

  // Division by zero (will abort, so we can't test it directly)
  // let a = match @decimal.Decimal::from_string("10.0") {
  //   Some(d) => d
  //   None => @decimal.zero()
  // }
  // let zero = @decimal.zero()
  // let result = a / zero  // This will abort

  // Invalid scale
  let invalid_scale = @decimal.Decimal::new(123N, -1)
  inspect(invalid_scale, content="None")
}
```

## Precision Notes

- **Scale**: Any non-negative integer
- **Default Scale**: 28 decimal places used by `/` (via `DEFAULT_SCALE`)
- **Zero Representation**: Always normalized to `coefficient=0, scale=0`

## Design Notes

The `Decimal` type is implemented using:
- **Coefficient**: A `BigInt` storing the significant digits
- **Scale**: An `Int` storing the number of decimal places
- **Normalization**: Automatic removal of trailing zeros
- **Exact Arithmetic**: All operations preserve exact decimal representation

This design ensures that financial calculations are always exact and predictable, avoiding the precision issues inherent in floating-point arithmetic.
