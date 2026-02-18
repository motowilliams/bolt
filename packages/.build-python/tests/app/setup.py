"""Setup configuration for calculator package."""
from setuptools import setup, find_packages

setup(
    name="calculator",
    version="0.1.0",
    description="Simple calculator for demonstration",
    author="Bolt Example",
    py_modules=["calculator"],
    python_requires=">=3.8",
    install_requires=[
        # No external dependencies for this simple example
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "black>=22.0.0",
            "flake8>=4.0.0",
        ]
    },
)
