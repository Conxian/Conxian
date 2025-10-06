#!/usr/bin/env python3
"""
StacksOrbit Setup Configuration
Professional GUI deployment tool for Stacks blockchain smart contracts
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read README for long description
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text(encoding="utf-8") if readme_file.exists() else ""

setup(
    name="stacksorbit",
    version="1.0.0",
    description="Professional GUI deployment tool for Stacks blockchain smart contracts with intelligent pre-checks and process control",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Anya Chain Labs",
    author_email="dev@anyachainlabs.com",
    url="https://github.com/Anya-org/stacksorbit",
    project_urls={
        "Bug Tracker": "https://github.com/Anya-org/stacksorbit/issues",
        "Documentation": "https://stacksorbit.dev",
        "Source Code": "https://github.com/Anya-org/stacksorbit",
        "Discussions": "https://github.com/Anya-org/stacksorbit/discussions",
    },
    packages=find_packages(exclude=["tests*", "docs*"]),
    py_modules=["stacksorbit"],
    entry_points={
        "console_scripts": [
            "stacksorbit=stacksorbit:main",
        ],
    },
    python_requires=">=3.8",
    install_requires=[
        # Python standard library modules (no additional dependencies needed)
        # tkinter is included with Python
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "black>=23.0.0",
            "pylint>=2.17.0",
            "mypy>=1.0.0",
        ],
        "test": [
            "pytest>=7.0.0",
            "pytest-mock>=3.10.0",
        ],
    },
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Build Tools",
        "Topic :: Software Development :: Testing",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Operating System :: OS Independent",
        "Operating System :: POSIX :: Linux",
        "Operating System :: Microsoft :: Windows",
        "Operating System :: MacOS",
        "Environment :: X11 Applications",
        "Environment :: Win32 (MS Windows)",
        "Environment :: MacOS X",
        "Topic :: Software Development",
        "Topic :: Utilities",
        "Topic :: System :: Systems Administration",
        "Framework :: AsyncIO",
    ],
    keywords=[
        "stacks",
        "blockchain",
        "smart-contracts",
        "deployment",
        "clarity",
        "gui",
        "devtools",
        "web3",
        "clarinet",
        "defi",
        "cryptocurrency",
        "bitcoin",
    ],
    license="MIT",
    platforms=["any"],
    include_package_data=True,
    package_data={
        "stacksorbit": [
            "*.md",
            "LICENSE",
            "requirements.txt",
        ],
    },
    zip_safe=False,
)
