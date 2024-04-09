# Reusable GitHub Actions workflows for DeepModeling

This repository holds [reusable GitHub Actions workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) for DeepModeling.
Read [GitHub documentation](https://docs.github.com/en/actions/using-workflows/reusing-workflows) to learn how to use them.

## Workflows

### `mirror_gitee.yml`

Mirror GitHub to Gitee. The SSH private key has been set globally across the DeepModeling organization.

### `release-to-pypi.yml`

Publish a pure Python package to PyPI. `PYPI_PASSWORD`, the PyPI token, is required to input.
