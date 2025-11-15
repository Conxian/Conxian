# GitHub Pages Setup Guide

This guide provides a step-by-step process for setting up a GitHub Pages site for the Conxian Protocol documentation.

## 1. Prerequisites

- You must have administrative access to the Conxian Protocol GitHub repository.
- The documentation files should be up-to-date and located in the `documentation` directory.

## 2. Recommended Setup: GitHub Actions

For maximum flexibility and to accommodate the project's complex documentation structure, we recommend using a GitHub Actions workflow to build and deploy the GitHub Pages site. This will allow you to use a static site generator like Jekyll or Hugo to create a professional-looking documentation site.

### Step 1: Create a GitHub Actions Workflow

1.  Create a new file in your repository at `.github/workflows/github-pages.yml`.
2.  Add the following content to the file:

```yaml
name: Deploy GitHub Pages

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm install

      - name: Build
        run: npm run build:docs # This command will need to be created

      - name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs # This should be the output directory of your build step
```

### Step 2: Create a Build Script

1.  In your `package.json` file, add a new script called `build:docs`. This script will be responsible for building your documentation site.
2.  The content of this script will depend on the static site generator you choose. For example, if you're using Jekyll, the script might look something like this:

```json
"scripts": {
  "build:docs": "jekyll build --source ./documentation --destination ./docs"
}
```

### Step 3: Configure Your Repository Settings

1.  In your repository's settings, go to the "Pages" tab.
2.  Under "Source," select "GitHub Actions."

## 3. Alternative Setup: Serve from a Directory

If you prefer a simpler setup, you can serve your GitHub Pages site directly from a directory in your repository.

### Step 1: Choose a Source Directory

1.  In your repository's settings, go to the "Pages" tab.
2.  Under "Source," select the branch you want to serve from (usually `main`).
3.  Select the directory you want to serve from. For this project, you should select `/documentation`.

### Step 2: Create an `index.md` File

1.  To ensure that your GitHub Pages site has a landing page, create a new file called `index.md` in the `documentation` directory.
2.  This file will be the main page of your documentation site. You can use the content from the `documentation/README.md` file as a starting point.

## 4. Next Steps

- Once you've set up GitHub Pages, you'll be able to access your documentation site at `https://<your-username>.github.io/<your-repository-name>`.
- You can customize the look and feel of your site by using a different static site generator or by creating your own custom theme.
- You can also add a custom domain to your site to give it a more professional look.

For more information on setting up GitHub Pages, see the official documentation: [https://docs.github.com/en/pages](https://docs.github.com/en/pages)
