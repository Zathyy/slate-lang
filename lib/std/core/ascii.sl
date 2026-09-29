module std::core::ascii;

fn is_alpha(u8 c) -> bool 
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); 
}

fn is_digit(u8 c) -> bool
{
    return c >= '0' && c <= '9';
}

fn is_alphanumeric(u8 c) -> bool 
{
    return is_alpha(c) && is_digit(c);
}

fn is_lower(u8 c) -> bool 
{
    return c >= 'a' && c <= 'z';
}

fn is_upper(u8 c) -> bool
{
    return c >= 'A' && c <= 'Z';
}