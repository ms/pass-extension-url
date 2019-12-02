# pass-extension-url

A [pass](https://www.passwordstore.org/) extension to get passwords for arbitrary URLs.

This extension allows you to copy paste your browser's URL (or any other URL, including non HTTP) and paste it in your terminal to get the corresponding password. Apart from the usability benefits, this should also make it less likely that you will fall prey to phishing since a mismatching URL won't find the phished-for file.

## Usage

```
  pass url [--clip[=line-number],-c[line-number]] [--force-any-scheme,-f] [--help, -h] URL
```

## Examples

```shell
# Get your google password
pass url 'https://accounts.google.com/signin/v2/sl/pwd?service=mail&passive=true&rm=false'
# => Matches accounts.google.com or google.com

# Don't get fished
pass url 'https://google.co.io/some/phishy/url'
# => Not found

# Warning if the scheme is not `https`
pass url http://mail.google.com/
# => "Error: URL scheme is not HTTPs. This may be the wrong site or insecure! -f to ignore"

# Ignore warning
pass url http://mail.google.com/ -f

# Also ignore warning
PASS_URL_IGNORE_NON_HTTPS=true pass url http://mail.google.com/ -f

# Copy second line
pass url https://mail.google.com/ -c2
```

## Installation

1. Clone the repository

```shell
git clone https://github.com/url/pass-extension-url
```

2. Copy or link the `.bash` file to `~/.password-store/.extensions/`

```shell
cp ./pass-extension-url/url.bash $HOME/.password-store/.extensions/
```

3. If you have not done so yet, enable home directory extensions

```shell
# In your .bashrc or .zshrc
export PASSWORD_STORE_ENABLE_EXTENSIONS=true
```

4. (Optional) Add the following to your `.bash_completion`

```shell
PASSWORD_STORE_EXTENSION_COMMANDS+=(url)
__password_store_extension_complete_url() {
  COMPREPLY+=($(compgen -W "-c --clip -h --help -f --force-any-scheme" -- ${cur}))
  _pass_complete_entries 1
 }
```

5. (Optional) Allow any URL scheme, add the following to your `.bashrc`

```shell
export PASS_URL_IGNORE_NON_HTTPS=true
```

## Thanks

Thanks to pass for the original tool (and code!). Thanks to the [pass-otp](https://github.com/tadfisher/pass-otp) extension for inspiration and healthy copying from its featureful code.
